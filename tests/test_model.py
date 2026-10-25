"""Independent software checks; run with python3 -m unittest discover -s tests."""
import random
import unittest
from sw.model import gemm, plan_tiles, requantize, tiled_gemm, wavefront, wrap_signed


class ModelTests(unittest.TestCase):
    def test_original_matrix(self):
        a = [[1,2,3,4],[5,6,7,8],[-1,2,-3,4],[8,0,1,-2]]
        b = [[1,0,2,-1],[3,1,0,2],[2,-2,1,1],[0,4,-1,3]]
        c = [[13,12,1,18],[37,24,9,38],[-1,24,-9,14],[10,-10,19,-13]]
        self.assertEqual(gemm(a,b), c)
        self.assertEqual(wavefront(a,b)["result"], c)

    def test_rounding_ties(self):
        self.assertEqual([requantize(x,shift=1,rounding=True) for x in (-5,-3,-1,1,3,5)], [-3,-2,-1,1,2,3])
        self.assertEqual(requantize(-3,shift=1), -2)

    def test_quantization_extremes(self):
        self.assertEqual(requantize(-(2**31),bias=-(2**31),multiplier=65535), -128)
        self.assertEqual(requantize(2**31-1,bias=2**31-1,multiplier=65535), 127)
        self.assertEqual(requantize(-1,shift=63), -1)
        self.assertEqual(requantize(-1,shift=63,rounding=True), 0)
        self.assertEqual(requantize(123,multiplier=0,zero_point=9), 9)

    def test_relu_at_quantized_zero(self):
        self.assertEqual(requantize(-40,zero_point=-11,relu=True), -11)
        self.assertEqual(requantize(40,zero_point=-11,relu=True), 29)

    def test_wraparound(self):
        self.assertEqual(wrap_signed(128,8), -128)
        self.assertEqual(wrap_signed(-129,8), 127)
        self.assertEqual(gemm([[-8,-8]], [[-8],[-8]],8), [[-128]])

    def test_wavefront_random_rectangles(self):
        rng=random.Random(329)
        for size in (1,2,3,4,8):
            for bits in (4,8):
                for _ in range(20):
                    m,n,k=rng.randint(1,size),rng.randint(1,size),rng.randint(1,17)
                    lo,hi=-(1<<(bits-1)),(1<<(bits-1))-1
                    a=[[rng.randint(lo,hi) for _ in range(k)] for _ in range(m)]
                    b=[[rng.randint(lo,hi) for _ in range(n)] for _ in range(k)]
                    r=wavefront(a,b,size,pauses={0,2,5,9,11})
                    self.assertEqual(r['result'],gemm(a,b))
                    self.assertEqual(r['compute_cycles'],k+m+n-2)
                    self.assertEqual(r['valid_macs'],m*n*k)
                    self.assertEqual(r['wall_cycles'],r['compute_cycles']+r['stall_cycles'])
                    self.assertEqual(r['zero_macs'],sum(a[i][x]==0 or b[x][j]==0 for i in range(m) for j in range(n) for x in range(k)))

    def test_host_tiling_and_tail_masks(self):
        rng=random.Random(55)
        for m,k,n in ((13,37,11),(1,1,1),(7,19,3),(4,17,4)):
            a=[[rng.randrange(-8,8) for _ in range(k)] for _ in range(m)]
            b=[[rng.randrange(-8,8) for _ in range(n)] for _ in range(k)]
            c,tiles=tiled_gemm(a,b,4,7)
            self.assertEqual(c,gemm(a,b))
            self.assertEqual(sum(t.rows*t.cols*t.depth for t in tiles),m*n*k)
            self.assertTrue(all(t.bank==i%2 for i,t in enumerate(tiles)))

    def test_ksplit_requantize_only_after_sum(self):
        a=[[1,1]]; b=[[1],[1]]
        c,_=tiled_gemm(a,b,1,1)
        self.assertEqual(requantize(c[0][0],shift=1),1)
        self.assertEqual(sum(requantize(x,shift=1) for x in (1,1)),0)

    def test_invalid_inputs(self):
        for args in ((0,1,1,4,16),(1,1,1,0,16)):
            with self.assertRaises(ValueError): plan_tiles(*args)
        with self.assertRaises(ValueError): gemm([[1,2]],[[1]])
        with self.assertRaises(ValueError): gemm([[1],[1,2]],[[1]])
        with self.assertRaises(ValueError): requantize(0,multiplier=65536)
        with self.assertRaises(ValueError): requantize(0,shift=64)
        with self.assertRaises(ValueError): requantize(0,zero_point=128)
        with self.assertRaises(ValueError): wavefront([[1],[2]],[[3]],1)


if __name__=='__main__': unittest.main()
