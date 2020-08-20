@testset "Constraints" begin
    #TODO needs to be updated for the new constraint design and interaction with Core
    T = Float64
    N = 3

    # Test extreme constraints
    c1(x) = x[1] < 1
    c2(x) = x[1] + x[3] > 1
    c3(x) = x[2] > 0

    p1(x) = x[1] < 1 ? 0 : x[1] - 1
    p2(x) = x[1] + x[3] > 1 ? 0 : 1 - x[1] + x[3]
    p3(x) = x[2] > 0 ? 0 : -x[2]

    C = DS.Constraints{T}()
    @testset "Constraints" begin
        @test C.count == length(C.collections) == 2
        @test typeof(C.collections[1]) == DS.ConstraintCollection{T, DS.ExtremeConstraint}
        @test typeof(C.collections[2]) == DS.ConstraintCollection{T, DS.ProgressiveConstraint}
    end

    @testset "DefaultConstraintCollection" begin
        ex = C.collections[1]
        pr = C.collections[2]

        # Extreme barrier constraint default collection
        @test length(ex.constraints) == ex.count ==  0
        @test typeof(ex.constraints) == Vector{DS.ExtremeConstraint}
        @test ex.h_max == 0.0

        # Extreme barrier constraint default collection
        @test length(pr.constraints) == pr.count == 0
        @test typeof(pr.constraints) == Vector{DS.ProgressiveConstraint}
        @test pr.h_max == Inf

        # TODO: Test default update functions
    end

    C = DS.Constraints{T}()
    @testset "AddExtremeConstraint" begin
        c1_ref = DS.AddExtremeConstraint(C, c1)
        @test c1_ref.value == 1
        @test typeof(c1_ref) == DS.ConstraintIndex

        # Can't push an extreme constraint to a progressive collection
        @test_throws MethodError DS.AddExtremeConstraint(C, c1, index=DS.CollectionIndex(2))
        @test_throws ErrorException DS.AddExtremeConstraint(C, c1, index=DS.CollectionIndex(3))

        vec_ref = DS.AddExtremeConstraint(C, [c2, c3])
        @test length(vec_ref) == 2
        @test vec_ref[1].value == 2
        @test vec_ref[2].value == 3
    end

    @testset "AddProgressiveConstraint" begin
        p1_ref = DS.AddProgressiveConstraint(C, p1)
        @test p1_ref.value == 1
        @test typeof(p1_ref) == DS.ConstraintIndex

        # Can't push an extreme constraint to a progressive collection
        @test_throws MethodError DS.AddProgressiveConstraint(C, p1, index=DS.CollectionIndex(1))
        @test_throws ErrorException DS.AddProgressiveConstraint(C, p1, index=DS.CollectionIndex(3))

        vec_ref = DS.AddProgressiveConstraint(C, [c2, c3])
        @test length(vec_ref) == 2
        @test vec_ref[1].value == 2
        @test vec_ref[2].value == 3
    end

    C = DS.Constraints{T}()
    @testset "AddProgressiveCollection" begin
        c_ref = DS.AddProgressiveCollection(C)
        @test typeof(c_ref) == DS.CollectionIndex
        @test c_ref.value == 3

        @test typeof(C.collections[3]) == DS.ConstraintCollection{T, DS.ProgressiveConstraint}
        @test length(C.collections[3].constraints) == C.collections[3].count == 0

        p_ref = DS.AddProgressiveConstraint(C, p2, index=c_ref)
        @test length(C.collections[3].constraints) == C.collections[3].count == 1
    end

    #TODO constraint evaluation
end
