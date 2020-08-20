@testset "Search" begin
    T = Float64
    @testset "NullSearch" begin
        p = DSProblem{T}(3, poll=LTMADS{T}())
        s = DS.NullSearch()
        @test DS.GenerateSearchPoints(p) == []
        @test DS.GenerateSearchPoints(p, s) == []
    end
    @testset "RandomSearch" begin
        N = 3
        c = generate_rand_cache(N, 10)
        d = 1.0
        s = DS.RandomSearch(10)

        points = DS.RandomPointsFromCache(N, c, d, s)

        for point in points
            mesh = keys(c.costs)
            closeness = [norm(point - m_point) ≈ d for m_point in mesh]
            @test true in closeness
        end
    end
end

