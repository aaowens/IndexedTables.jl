using Base.Test
using NDSparseData

let a = NDSparse([12,21,32], [52,41,34], [11,53,150]), b = NDSparse([12,23,32], [52,43,34], [56,13,10])
    c = naturaljoin(a, b, +)
    @test c[12,52] == 67
    @test c[32,34] == 160
    @test length(c.index) == 2

    c = select(a, 1=>x->x<30, 2=>x->x>40)
    @test c[12,52] == 11
    @test c[21,41] == 53
    @test length(c.index) == 2

    c = filter(x->x>100, a)
    @test c[32,34] == 150
    @test length(c.index) == 1
end

let a = NDSparse([1,1,2,2], [1,2,1,2], [6,7,8,9])
    @test select(a, 1, agg=+) == NDSparse([1,2], [13,17])
    @test select(a, 2, agg=+) == NDSparse([1,2], [14,16])
end

@test leftjoin(NDSparse([1,1,1,2], [2,3,4,4], [5,6,7,8]),
               NDSparse([1,1,3],   [2,4,4],   [9,10,12])) ==
                   NDSparse([1,1,1,2], [2,3,4,4], [9, 6, 10, 8])

@test leftjoin(NDSparse([1,1,1,2], [2,3,4,4], [5,6,7,8]),
               NDSparse([1,1,2],   [2,4,4],   [9,10,12])) ==
                   NDSparse([1,1,1,2], [2,3,4,4], [9, 6, 10, 12])

@test asofjoin(NDSparse([:msft,:ibm,:ge], [1,3,4], [100,200,150]),
               NDSparse([:ibm,:msft,:msft,:ibm], [0,0,0,2], [100,99,101,98])) ==
                   NDSparse([:msft,:ibm,:ge], [1,3,4], [101, 98, 150])

@test asofjoin(NDSparse([:AAPL, :IBM, :MSFT], [45, 512, 454], [63, 93, 54]),
               NDSparse([:AAPL, :MSFT, :AAPL], [547,250,34], [88,77,30])) ==
                   NDSparse([:AAPL, :MSFT, :IBM], [45, 454, 512], [30, 77, 93])

@test asofjoin(NDSparse([:aapl,:ibm,:msft,:msft],[1,1,1,3],[4,5,6,7]),
               NDSparse([:aapl,:ibm,:msft],[0,0,0],[8,9,10])) ==
                   NDSparse([:aapl,:ibm,:msft,:msft],[1,1,1,3],[8,9,10,10])
