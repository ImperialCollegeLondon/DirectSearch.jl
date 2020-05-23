@testset "OrthoMADS" begin
    @testset "Initialisation" begin

        #Check that constructor defaults to parametric type Float64
        _om = OrthoMADS(3)
        om = OrthoMADS{Float64}(3)
        @test _om.l == om.l
        @test _om.Δᵖmin == om.Δᵖmin
        @test _om.t₀ == om.t₀
        @test _om.t == om.t
        @test _om.tmax == om.tmax


        #Check that expected values are given for n=5
        @test om.l == 0
        @test om.Δᵖmin == 1.0
        @test om.t == 5
        @test om.t₀ == 5
        @test om.tmax == 5

        om = OrthoMADS{Float64}(5)


        #Check that expected values are given for n=11
        @test om.l == 0
        @test om.Δᵖmin == 1.0
        @test om.t == 11
        @test om.t₀ == 11
        @test om.tmax == 11

        #Check that error is raised for negative and 0 valued n
        @test_throws DomainError OrthoMADS{Float64}(0)
        @test_throws DomainError OrthoMADS{Float64}(-1)
    end

    @testset "MeshUpdate" begin
        input(N) = (DS.Mesh(N), OrthoMADS(N))
        @testset "mesh index, l" begin
            #=
            Combining rules from progressive barrier and OrthoMADS, the index
            should decrement on a successful iteration (dominating), stay the same
            on an improving iteration, and increment on a failure.
            =#
            m, o = input(4)
            @test o.l == 0
            DS.MeshUpdate!(m, o, DS.Dominating)
            @test o.l == -1
            DS.MeshUpdate!(m, o, DS.Dominating)
            @test o.l == -2

            DS.MeshUpdate!(m, o, DS.Improving)
            @test o.l == -2
            DS.MeshUpdate!(m, o, DS.Improving)
            @test o.l == -2

            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test o.l == -1
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test o.l == 0

            DS.MeshUpdate!(m, o, DS.Improving)
            @test o.l == 0
            DS.MeshUpdate!(m, o, DS.Improving)
            @test o.l == 0

            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test o.l == 1
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test o.l == 2

            DS.MeshUpdate!(m, o, DS.Improving)
            @test o.l == 2
            DS.MeshUpdate!(m, o, DS.Improving)
            @test o.l == 2
        end

        @testset "poll size parameter, Δᵖ" begin
            m, o = input(4)

            #= Should evaluate to 2^-l =#
            @test m.Δᵖ == 1.0
            DS.MeshUpdate!(m, o, DS.Dominating)
            @test m.Δᵖ == 2.0
            DS.MeshUpdate!(m, o, DS.Dominating)
            @test m.Δᵖ == 4.0

            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵖ == 4.0
            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵖ == 4.0

            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test m.Δᵖ == 2.0
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test m.Δᵖ == 1.0

            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵖ == 1.0
            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵖ == 1.0

            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test m.Δᵖ == 0.5
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test m.Δᵖ == 0.25
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test m.Δᵖ == 0.125
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test m.Δᵖ == 0.0625

            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵖ == 0.0625
            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵖ == 0.0625
        end
        @testset "mesh size parameter, Δᵐ" begin
            m, o = input(4)

            #= Should evaluate to min(1, 4^(-l)) =#
            @test m.Δᵐ == 1.0
            DS.MeshUpdate!(m, o, DS.Dominating)
            @test m.Δᵐ == 1.0
            DS.MeshUpdate!(m, o, DS.Dominating)
            @test m.Δᵐ == 1.0

            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵐ == 1.0
            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵐ == 1.0

            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test m.Δᵐ == 1.0
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test m.Δᵐ == 1.0

            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵐ == 1.0
            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵐ == 1.0

            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test m.Δᵐ == 0.25
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            @test m.Δᵐ == 0.0625

            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵐ == 0.0625
            DS.MeshUpdate!(m, o, DS.Improving)
            @test m.Δᵐ == 0.0625
        end
        @testset "Halton index, tᵐ" begin
            m, o = input(4)
            
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
            
            DS.MeshUpdate!(m, o, DS.Improving)
            #Poll size remains the same, ∴ t = tmax = 7 + 1
            @test o.t == 8
            @test o.tmax == 8
            @test o.t₀ == 7

            DS.MeshUpdate!(m, o, DS.Dominating)
            #Poll size increases, ∴ t = tmax + 1 =  8 + 1 = 9
            @test o.t == 9
            @test o.tmax == 9
            @test o.t₀ == 7

            DS.MeshUpdate!(m, o, DS.Dominating)
            #Poll size increases, ∴ t = tmax + 1 = 9 + 1 = 10
            @test o.t == 10
            @test o.tmax == 10
            @test o.t₀ == 7

            DS.MeshUpdate!(m, o, DS.Improving)
            #Poll size remains the same, ∴ t = tmax + 1 = 10 + 1 = 11
            @test o.t == 11
            @test o.tmax == 11
            @test o.t₀ == 7

            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            #Poll decreases but is larger than min, ∴ t = tmax + 1 = 11 + 1 = 12
            @test o.t == 12
            @test o.tmax == 12
            @test o.t₀ == 7

            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            #Poll decreases but is larger than min, ∴ t = tmax + 1 = 12 + 1 = 13
            @test o.t == 13
            @test o.tmax == 13
            @test o.t₀ == 7

            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            #Poll decreases to new min, and l=1, ∴ t = l + t₀ = 8
            @test o.t == 8
            @test o.tmax == 13
            @test o.t₀ == 7

            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            #Poll decreases to new min, and l=2, ∴ t = l + t₀ = 9
            @test o.t == 9
            @test o.tmax == 13
            @test o.t₀ == 7

            DS.MeshUpdate!(m, o, DS.Improving)
            #Poll remains the same, ∴ t = tmax + 1 = 13 + 1 = 14
            @test o.t == 14 
            @test o.tmax == 14
            @test o.t₀ == 7

            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            #Poll decreases to new min, and l=3, ∴ t = l + t₀ = 10
            @test o.t == 10
            @test o.tmax == 14
            @test o.t₀ == 7


            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            DS.MeshUpdate!(m, o, DS.Unsuccessful)
            #Multiple decreases will update tmax 
            @test o.t == 15
            @test o.tmax == 15
            @test o.t₀ == 7

        end
    end
end

