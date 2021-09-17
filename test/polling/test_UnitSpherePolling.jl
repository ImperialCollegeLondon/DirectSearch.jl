using DirectSearch
using LinearAlgebra
using Random
using Test

# Make sure we get a unit sphere point back
let poll = UnitSpherePolling()
    # Intitialize the random number seed
    Random.seed!( 12345 )

    D = DirectSearch._sample_unit_sphere( Random.default_rng(), 5 )

    Dact = [ 0.6756026398328625;
             0.49139549679631706;
             0.23948057804151515;
             0.29760363963456393;
             0.39518687376522355]

    @test size( D ) == (5, )
    @test norm( D ) ≈ 1.0
    @test D ≈ Dact
end

# Test with a custom RNG
let poll = UnitSpherePolling()
    rng = MersenneTwister( 11111 )
    D = DirectSearch._sample_unit_sphere( rng, 5 )

    Dact = [ -0.38057200197865854;
             -0.13456115505963132;
              0.7286166384654709;
              0.3450540305104261;
             -0.43256647701684076]

    @test size( D ) == (5, )
    @test norm( D ) ≈ 1.0
    @test D ≈ Dact
end

struct TestProblem <: DirectSearch.AbstractProblem{Float64}
    N::Int
end

# Test the generated directions
let t = TestProblem( 5 )
    p = UnitSpherePolling()

    D = DirectSearch.GenerateDirections( t, p )

    # Should return 2N directions
    @test size( D ) == (5, 10)
end
