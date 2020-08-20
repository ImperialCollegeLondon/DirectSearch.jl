using LinearAlgebra

@testset "OrthoMADS" begin
    @testset "Initialisation" begin

        #Check that constructor defaults to parametric type Float64
        _om = OrthoMADS()
        om = OrthoMADS{Float64,Int64}()

        @test isdefined(om, :t)
        @test isdefined(om, :tmax)
        @test isdefined(om, :t₀)
        @test _om.l == om.l
        @test _om.init_run == om.init_run
        @test _om.Δᵖmin == om.Δᵖmin
        @test om.l == 0
        @test om.init_run == false
        @test om.Δᵖmin == 1.0

        primes = [
           2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61,
           67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137,
           139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211,
           223, 227, 229
        ]

        for N = 1:50
            om = OrthoMADS{Float64,Int64}()
            @test om.init_run == false
            DS.init_orthomads(N, om)
            @test om.t == om.tmax == om.t₀ == primes[N]
            @test om.init_run == true
        end
    end

    @testset "MeshUpdate" begin
        @testset "mesh index, l" begin
            #=
            Combining rules from progressive barrier and OrthoMADS, the index
            should decrement on a successful iteration (dominating), stay the same
            on an improving iteration, and increment on a failure.
            =#
            p = DSProblem(4;poll=OrthoMADS())
            m = p.config.mesh
            o = p.config.poll
           @test m.l == 0
            DS.MeshUpdate!(p, DS.Dominating)
            @test m.l == -1
            DS.MeshUpdate!(p, DS.Dominating)
            @test m.l == -2

            DS.MeshUpdate!(p, DS.Improving)
            @test m.l == -2
            DS.MeshUpdate!(p, DS.Improving)
            @test m.l == -2

            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.l == -1
            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.l == 0

            DS.MeshUpdate!(p, DS.Improving)
            @test m.l == 0
            DS.MeshUpdate!(p, DS.Improving)
            @test m.l == 0

            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.l == 1
            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.l == 2

            DS.MeshUpdate!(p, DS.Improving)
            @test m.l == 2
            DS.MeshUpdate!(p, DS.Improving)
            @test m.l == 2
        end

        @testset "poll size parameter, Δᵖ" begin
            p = DSProblem(4;poll=OrthoMADS())
            m = p.config.mesh
            o = p.config.poll

            #= Should evaluate to 2^-l =#
            @test m.Δᵖ == 1.0
            DS.MeshUpdate!(p, DS.Dominating)
            @test m.Δᵖ == 2.0
            DS.MeshUpdate!(p, DS.Dominating)
            @test m.Δᵖ == 4.0

            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵖ == 4.0
            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵖ == 4.0

            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.Δᵖ == 2.0
            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.Δᵖ == 1.0

            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵖ == 1.0
            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵖ == 1.0

            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.Δᵖ == 0.5
            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.Δᵖ == 0.25
            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.Δᵖ == 0.125
            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.Δᵖ == 0.0625

            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵖ == 0.0625
            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵖ == 0.0625
        end
        @testset "mesh size parameter, Δᵐ" begin
            p = DSProblem(4;poll=OrthoMADS())
            m = p.config.mesh
            o = p.config.poll

            #= Should evaluate to min(1, 4^(-l)) =#
            @test m.Δᵐ == 1.0
            DS.MeshUpdate!(p, DS.Dominating)
            @test m.Δᵐ == 1.0
            DS.MeshUpdate!(p, DS.Dominating)
            @test m.Δᵐ == 1.0

            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵐ == 1.0
            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵐ == 1.0

            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.Δᵐ == 1.0
            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.Δᵐ == 1.0

            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵐ == 1.0
            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵐ == 1.0

            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.Δᵐ == 0.25
            DS.MeshUpdate!(p, DS.Unsuccessful)
            @test m.Δᵐ == 0.0625

            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵐ == 0.0625
            DS.MeshUpdate!(p, DS.Improving)
            @test m.Δᵐ == 0.0625
        end
        @testset "Halton index, tᵐ" begin
            N = 4
            p = DSProblem(N; poll=OrthoMADS())
            m = p.config.mesh
            o = p.config.poll
            DS.init_orthomads(N, o)

            #=
            If the poll size is the smallest so far then:
                t = l + t₀
            Otherwise:
                t = 1 + tmax


            tmax is the largest considered value of t
            t₀ stays constant
            =#
            @test o.t == 7 #the 4th prime number
            @test o.tmax == 7
            @test o.t₀ == 7

            #Successful (dominating) iterations cause a decrease in poll size
            #Improving iterations cause no change in poll size
            #Failed iterations cause an increase in poll size

            DS.MeshUpdate!(p, DS.Improving)
            #Poll size remains the same, ∴ t = tmax = 7 + 1
            @test o.t == 8
            @test o.tmax == 8
            @test o.t₀ == 7

            DS.MeshUpdate!(p, DS.Dominating)
            #Poll size increases, ∴ t = tmax + 1 =  8 + 1 = 9
            @test o.t == 9
            @test o.tmax == 9
            @test o.t₀ == 7

            DS.MeshUpdate!(p, DS.Dominating)
            #Poll size increases, ∴ t = tmax + 1 = 9 + 1 = 10
            @test o.t == 10
            @test o.tmax == 10
            @test o.t₀ == 7

            DS.MeshUpdate!(p, DS.Improving)
            #Poll size remains the same, ∴ t = tmax + 1 = 10 + 1 = 11
            @test o.t == 11
            @test o.tmax == 11
            @test o.t₀ == 7

            DS.MeshUpdate!(p, DS.Unsuccessful)
            #Poll decreases but is larger than min, ∴ t = tmax + 1 = 11 + 1 = 12
            @test o.t == 12
            @test o.tmax == 12
            @test o.t₀ == 7

            DS.MeshUpdate!(p, DS.Unsuccessful)
            #Poll decreases but is larger than min, ∴ t = tmax + 1 = 12 + 1 = 13
            @test o.t == 13
            @test o.tmax == 13
            @test o.t₀ == 7

            DS.MeshUpdate!(p, DS.Unsuccessful)
            #Poll decreases to new min, and l=1, ∴ t = l + t₀ = 8
            @test o.t == 8
            @test o.tmax == 13
            @test o.t₀ == 7

            DS.MeshUpdate!(p, DS.Unsuccessful)
            #Poll decreases to new min, and l=2, ∴ t = l + t₀ = 9
            @test o.t == 9
            @test o.tmax == 13
            @test o.t₀ == 7

            DS.MeshUpdate!(p, DS.Improving)
            #Poll remains the same, ∴ t = tmax + 1 = 13 + 1 = 14
            @test o.t == 14
            @test o.tmax == 14
            @test o.t₀ == 7

            DS.MeshUpdate!(p, DS.Unsuccessful)
            #Poll decreases to new min, and l=3, ∴ t = l + t₀ = 10
            @test o.t == 10
            @test o.tmax == 14
            @test o.t₀ == 7


            DS.MeshUpdate!(p, DS.Unsuccessful)
            DS.MeshUpdate!(p, DS.Unsuccessful)
            DS.MeshUpdate!(p, DS.Unsuccessful)
            DS.MeshUpdate!(p, DS.Unsuccessful)
            DS.MeshUpdate!(p, DS.Unsuccessful)
            #Multiple decreases will update tmax
            @test o.t == 15
            @test o.tmax == 15
            @test o.t₀ == 7
        end
    end

    @testset "HaltonCoefficient" begin
        #=
        Finds the coefficients (a) of the base p expansion of t:

        t = sum(a*p^r) for r = [0,∞]
        =#
        p=2
        @test DS.HaltonCoefficient(p, 0) == []
        @test DS.HaltonCoefficient(p, 1) == [1]
        @test DS.HaltonCoefficient(p, 2) == [0, 1]
        @test DS.HaltonCoefficient(p, 3) == [1, 1]
        @test DS.HaltonCoefficient(p, 4) == [0, 0, 1]
        @test DS.HaltonCoefficient(p, 5) == [1, 0, 1]
        @test DS.HaltonCoefficient(p, 6) == [0, 1, 1]
        @test DS.HaltonCoefficient(p, 7) == [1, 1, 1]
        @test DS.HaltonCoefficient(p, 8) == [0, 0, 0, 1]
        @test DS.HaltonCoefficient(p, 9) == [1, 0, 0, 1]

        p=3
        @test DS.HaltonCoefficient(p, 0) == []
        @test DS.HaltonCoefficient(p, 1) == [1]
        @test DS.HaltonCoefficient(p, 2) == [2]
        @test DS.HaltonCoefficient(p, 3) == [0, 1]
        @test DS.HaltonCoefficient(p, 4) == [1, 1]
        @test DS.HaltonCoefficient(p, 5) == [2, 1]
        @test DS.HaltonCoefficient(p, 6) == [0, 2]
        @test DS.HaltonCoefficient(p, 7) == [1, 2]
        @test DS.HaltonCoefficient(p, 8) == [2, 2]
        @test DS.HaltonCoefficient(p, 9) == [0, 0, 1]

        p=5
        @test DS.HaltonCoefficient(p, 0) == []
        @test DS.HaltonCoefficient(p, 1) == [1]
        @test DS.HaltonCoefficient(p, 2) == [2]
        @test DS.HaltonCoefficient(p, 3) == [3]
        @test DS.HaltonCoefficient(p, 4) == [4]
        @test DS.HaltonCoefficient(p, 5) == [0, 1]
        @test DS.HaltonCoefficient(p, 6) == [1, 1]
        @test DS.HaltonCoefficient(p, 7) == [2, 1]
        @test DS.HaltonCoefficient(p, 8) == [3, 1]
        @test DS.HaltonCoefficient(p, 9) == [4, 1]

        p=7
        @test DS.HaltonCoefficient(p, 0) == []
        @test DS.HaltonCoefficient(p, 1) == [1]
        @test DS.HaltonCoefficient(p, 2) == [2]
        @test DS.HaltonCoefficient(p, 3) == [3]
        @test DS.HaltonCoefficient(p, 4) == [4]
        @test DS.HaltonCoefficient(p, 5) == [5]
        @test DS.HaltonCoefficient(p, 6) == [6]
        @test DS.HaltonCoefficient(p, 7) == [0, 1]
        @test DS.HaltonCoefficient(p, 8) == [1, 1]
        @test DS.HaltonCoefficient(p, 9) == [2, 1]
    end

    @testset "HalonEntry" begin
        #=
        Calculates the radical inverse function in base p:

        u = sum(a/p^(1+r)) for r=[0,∞]
        =#

        t = 0
        @test DS.HaltonEntry(2, t) ≈ 0
        @test DS.HaltonEntry(3, t) ≈ 0
        @test DS.HaltonEntry(5, t) ≈ 0
        @test DS.HaltonEntry(7, t) ≈ 0

        t = 1
        @test DS.HaltonEntry(2, t) ≈ 1/2
        @test DS.HaltonEntry(3, t) ≈ 1/3
        @test DS.HaltonEntry(5, t) ≈ 1/5
        @test DS.HaltonEntry(7, t) ≈ 1/7

        t = 2
        @test DS.HaltonEntry(2, t) ≈ 1/4
        @test DS.HaltonEntry(3, t) ≈ 2/3
        @test DS.HaltonEntry(5, t) ≈ 2/5
        @test DS.HaltonEntry(7, t) ≈ 2/7

        t = 3
        @test DS.HaltonEntry(2, t) ≈ 3/4
        @test DS.HaltonEntry(3, t) ≈ 1/9
        @test DS.HaltonEntry(5, t) ≈ 3/5
        @test DS.HaltonEntry(7, t) ≈ 3/7

        t = 4
        @test DS.HaltonEntry(2, t) ≈ 1/8
        @test DS.HaltonEntry(3, t) ≈ 4/9
        @test DS.HaltonEntry(5, t) ≈ 4/5
        @test DS.HaltonEntry(7, t) ≈ 4/7

        t = 5
        @test DS.HaltonEntry(2, t) ≈ 5/8
        @test DS.HaltonEntry(3, t) ≈ 7/9
        @test DS.HaltonEntry(5, t) ≈ 1/25
        @test DS.HaltonEntry(7, t) ≈ 5/7

        t = 6
        @test DS.HaltonEntry(2, t) ≈ 3/8
        @test DS.HaltonEntry(3, t) ≈ 2/9
        @test DS.HaltonEntry(5, t) ≈ 6/25
        @test DS.HaltonEntry(7, t) ≈ 6/7

        t = 7
        @test DS.HaltonEntry(2, t) ≈ 7/8
        @test DS.HaltonEntry(3, t) ≈ 5/9
        @test DS.HaltonEntry(5, t) ≈ 11/25
        @test DS.HaltonEntry(7, t) ≈ 1/49
    end

    @testset "Halton" begin
        N = 4

        t = 0
        @test DS.Halton(N, t) ≈ [0,0,0,0]

        t = 1
        @test DS.Halton(N, t) ≈ [1/2,1/3,1/5,1/7]

        t = 2
        @test DS.Halton(N, t) ≈ [1/4,2/3,2/5,2/7]

        t = 3
        @test DS.Halton(N, t) ≈ [3/4,1/9,3/5,3/7]

        t = 4
        @test DS.Halton(N, t) ≈ [1/8,4/9,4/5,4/7]

        t = 5
        @test DS.Halton(N, t) ≈ [5/8,7/9,1/25,5/7]

        t = 6
        @test DS.Halton(N, t) ≈ [3/8, 2/9, 6/25, 6/7]

        t = 7
        @test DS.Halton(N, t) ≈ [7/8, 5/9, 11/25, 1/49]
    end

    @testset "AdjustedHaltonFamily" begin
        f = DS.AdjustedHaltonFamily([1/2, 1/3, 1/5, 1/7])
        @test f(0) ≈ [0.0,0.0,0.0,0.0]
        @test f(1) ≈ [0.0,0.0,-1.0,-1.0]
        @test f(2) ≈ [0.0,-1.0,-1.0,-1.0]
        @test f(3) ≈ [0.0,-1.0,-2.0,-2.0]
        @test f(4) ≈ [0.0,-1.0,-2.0,-3.0]
        @test f(5) ≈ [0.0,-2.0,-3.0,-4.0]
    end

    @testset "argmax" begin
        #General argmax test, due to the rounding also done, being within 0.1 is more than
        #sufficient
        f(x) = 0.1x^2 + x
        @test isapprox(DS.argmax(0, f, 6), 4.2195444, atol=0.1)

        g = DS.AdjustedHaltonFamily([7/8,5/9,11/25,1/49])
        @test isapprox(DS.argmax(0.0, x->norm(g(x)), 1.0), 0.8, atol = 0.1)

        h = DS.AdjustedHaltonFamily([7/16,22/27,22/25,2/49])
        @test isapprox(DS.argmax(5.156854249492381, x->norm(h(x)), 11.313708498984761), 11.5, atol = 0.1)
    end

    @testset "AdjustedHalton" begin
        N = 4

        t = 7; l = 0
        @test DS.AdjustedHalton([7/8,5/9,11/25,1/49], N, l) == [0.0, 0.0, 0.0, -1.0]

        t = 8; l = 1
        @test DS.AdjustedHalton([1/16,8/9,16/25,8/49], N, l) == [-1.0, 1.0, 0.0, 0.0]

        t = 9; l = 2
        @test DS.AdjustedHalton([9/16,1/27,21/25,15/49], N, l) == [0.0, -1.0, 1.0, -1.0]

        t = 10; l = 3
        @test DS.AdjustedHalton([5/16,10/27,2/25,22/49], N, l) == [-1.0, -1.0, -2.0, 0.0]

        t = 11; l = 4
        @test DS.AdjustedHalton([13/16,19/27,7/25,29/49], N, l) == [2.0, 2.0, -2.0, 1.0]

        t = 12; l = 5
        @test DS.AdjustedHalton([3/16,4/27,12/25,36/49], N, l) == [-3.0, -4.0, 0.0, 2.0]

        t = 13; l = 6
        @test DS.AdjustedHalton([11/16,13/27,17/25,43/49], N, l) == [3.0, 0.0, 3.0, 6.0]

        t = 14; l = 7
        @test DS.AdjustedHalton([7/16,22/27,22/25,2/49], N, l) == [-1.0, 5.0, 6.0, -8.0]
    end

    @testset "Householder Transform" begin
        @test DS.HouseholderTransform([-1.0, 5.0, 6.0, -8.0]) ≈
											[124.0   10.0   12.0  -16.0;
											  10.0   76.0  -60.0   80.0;
											  12.0  -60.0   54.0   96.0;
											 -16.0   80.0   96.0   -2.0]
    end

	@testset "Basis Generation" begin
        N = 4
        DS.GenerateOMBasis(N, 7, 0)  ==  [1 0 0 0;    0 1 0 0; 0 0 1 0; 0 0 0 -1]
        DS.GenerateOMBasis(N, 8, 1)  ==  [0 2 0 0;    2 0 0 0; 0 0 2 0; 0 0 0 2]
        DS.GenerateOMBasis(N, 9, 2)  ==  [3 0 0 0;    0 1 2 -2; 0 2 1 2; 0 -2 2 1]
        DS.GenerateOMBasis(N, 10, 3) == [4 -2 -4 0; -2 4 -4 0; -4 -4 -4 0; 0 0 0 6]
        DS.GenerateOMBasis(N, 11, 4) == [5 -8 8 -4; -8 5 8 -4; 8 8 5 4; -4 -4 4 11]
        DS.GenerateOMBasis(N, 12, 5) == [11 -24 0 12; -24 -3 0 16; 0 0 29 0; 12 16 0 21]
        DS.GenerateOMBasis(N, 13, 6) == [36 0 -18 -36; 0 54 0 0; -18 0 36 -36; -36 0 -36 -18]
        DS.GenerateOMBasis(N, 14, 7) == [124 10 12 -16; 10 76 -60 80; 12 -60 54 96; -16 80 96 -2]
	end

    @testset "GenerateDirections" begin
        p = DSProblem(4; poll=OrthoMADS())
        #Initially t=7, l=0
        D = [1 0 0 0 -1 0 0 0; 0 1 0 0 0 -1 0 0; 0 0 1 0 0 0 -1 0; 0 0 0 -1 0 0 0 1]
        @test DS.GenerateDirections(p) == D
        @test DS.GenerateDirections(p, p.config.poll) == D
        @test DS.GenerateDirections(4, p.config.poll) == D
    end
end

