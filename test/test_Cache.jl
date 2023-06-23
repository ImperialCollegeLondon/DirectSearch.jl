
function generate_rand_cache(N, M; T=Float64, range=-100.0:100.0)
    cache = DS.PointCache{T}()
    for _ in 1:M
        DS.CachePush(cache, rand(range,N), rand(range))
    end
    return cache
end


@testset "Cache" begin
    T = Float64
    c = DS.PointCache{T}()
    @testset "Constructor" begin
        @test typeof(c.costs) == Dict{Vector{T},T}
        @test length(c.costs) == 0
        @test typeof(c.order) == Vector{Vector{T}}
        @test length(c.order) == 0
    end

    @testset "CachePush" begin
        @test_throws MethodError DS.CachePush(c, [1,2,3], 1)
        @test_throws MethodError DS.CachePush(c, [1.0,2.0,3.0], 1)
        @test_throws MethodError DS.CachePush(c, [1,2,3], 1.0)

        DS.CachePush(c, [1.0,2.0,3.0], 4.0)
        @test c.costs[[1.0,2.0,3.0]] == 4.0

        DS.CachePush(c, [1.0,2.0,3.0], 6.0)
        @test c.costs[[1.0,2.0,3.0]] == 6.0

        DS.CachePush(c, [4.21, 45.0, 1234321.0], 2112.0)
        @test c.costs[[1.0,2.0,3.0]] == 6.0
        @test c.costs[[4.21, 45.0, 1234321.0]] == 2112.0
    end

    @testset "CacheOrderPush" begin
        @test c.order == []
        DS.CacheOrderPush(c, nothing)
        @test c.order == []
        DS.CacheOrderPush(c, [1.0, 2.0, 3.0])
        @test c.order == [[1.0, 2.0, 3.0]]
        DS.CacheOrderPush(c, [2.0, 2.0, 2.0])
        @test c.order == [[1.0, 2.0, 3.0], [2.0, 2.0, 2.0]]
        DS.CacheOrderPush(c, [2.0, 2.0, 2.0])
        @test c.order == [[1.0, 2.0, 3.0], [2.0, 2.0, 2.0]]
        DS.CacheOrderPush(c, [1.0, 2.0, 3.0])
        @test c.order == [[1.0, 2.0, 3.0], [2.0, 2.0, 2.0],[1.0, 2.0, 3.0]]
    end

    @testset "CacheQuery" begin
        @test_throws MethodError DS.CacheQuery(c, [1,2,3])

        @test DS.CacheQuery(c, [1.0,2.0,3.0])
        @test !DS.CacheQuery(c, [1.0,1.0,1.0])
    end

    @testset "CacheGet" begin
        @test_throws MethodError DS.CacheGet(c, [1,2,3])

        @test DS.CacheGet(c, [4.21, 45.0, 1234321.0]) == 2112.0
        @test DS.CacheGet(c, [1.0,2.0,3.0]) ==  6.0
        @test_throws KeyError DS.CacheGet(c, [1.0,2.0,4.0])
     end

    @testset "CacheRandomSample" begin
        @test DS.CacheRandomSample(c, 0) == []
        @test DS.CacheRandomSample(c, 1)[1] in c.order
        @test length(DS.CacheRandomSample(c, 1)) == 1
        @test all(p in c.order for p in DS.CacheRandomSample(c, 10))
        @test length(DS.CacheRandomSample(c, 2)) == 2
    end

    @testset "CacheInitialPoint" begin
        @test_throws BoundsError DS.CacheInitialPoint(DS.PointCache{T}())
        @test DS.CacheInitialPoint(c) == ([1.0,2.0,3.0], 6.0)
    end

    @testset "CacheGetRange" begin
        @test DS.CacheGetRange(c, [[4.21, 45.0, 1234321.0], [1.0,2.0,3.0]]) == [2112.0, 6.0]
        @test DS.CacheGetRange(c, []) == []
        @test_throws KeyError DS.CacheGetRange(c, [[4.21, 45.0, 1234321.0], [1.0,2.0,4.0]])

    end

    @testset "CacheFilter" begin
        @test DS.CacheFilter(c, [[4.21, 45.0, 1234321.0], [1.0,2.0,3.0], [7.0,8.0,9.0]]) ==
              ([[4.21, 45.0, 1234321.0], [1.0,2.0,3.0]], [[7.0,8.0,9.0]])
        @test DS.CacheFilter(c, [[4.21, 45.0, 1234321.0], [1.0,2.0,3.0]]) ==
              ([[4.21, 45.0, 1234321.0], [1.0,2.0,3.0]], [])
        @test DS.CacheFilter(c, [[4.22, 68.0, -1114754.0], [8.0,1.0,2.0]]) ==
              ([], [[4.22, 68.0, -1114754.0], [8.0,1.0,2.0]])
        @test DS.CacheFilter(c, []) == ([], [])

    end
end
