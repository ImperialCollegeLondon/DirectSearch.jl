using DirectSearch
using Test

@testset "get_decimal_places" begin
    @test DS.get_decimal_places(0.0) === nothing
    @test DS.get_decimal_places(1) == 0
    @test DS.get_decimal_places(1.0) == 0
    @test DS.get_decimal_places(0.1) == 1
end

@testset "get_poll_size_estimate" begin
    #no bounds and zero initial value
    @test DS.get_poll_size_estimate(0, nothing, nothing) == 1.0

    #no bounds and initial value different than zero
    @test DS.get_poll_size_estimate(100, nothing, nothing) == 10.0

    # one finite bound equal to initial value
    @test DS.get_poll_size_estimate(30, 30, nothing) == 3.0
    @test DS.get_poll_size_estimate(30, nothing, 30) == 3.0

    #one finite bound different than initial value
    @test DS.get_poll_size_estimate(100, 700, nothing) == 60.0
    @test DS.get_poll_size_estimate(100, nothing, 700) == 60.0

    #both finite bounds where l < u
    @test DS.get_poll_size_estimate(50, 100, 500) == 40.0

    #both finite bounds where l > u
    @test DS.get_poll_size_estimate(50, 500, 100) == 5.0
end

@testset "SetMeshSizeVector" begin
    m = DS.AnisotropicMesh(2)
    m.δ_min = [0.0, 2.0]
    m.b = [3.0, 5.0]
    m.b⁰ = [1.0, 2.0]

    DS.SetMeshSizeVector!(m)

    @test m.δ[1] == 10.0
    @test m.δ[2] == 200.0
end

@testset "SetPollSizeVector" begin
    m = DS.AnisotropicMesh(2)
    m.δ_min = [0.0, 2.0]
    m.a = [1.0, 3.0]
    m.b = [3.0, 5.0]

    DS.SetPollSizeVector!(m)

    @test m.Δ[1] == 1000.0
    @test m.Δ[2] == 600000.0
end

@testset "SetRatioVector" begin
    m = DS.AnisotropicMesh(2)
    m.δ_min = [0.0, 2.0]
    m.Δ = [30.0, 60.0]
    m.δ = [10.0, 1.0]

    DS.SetRatioVector!(m)

    @test m.ρ == [3.0, 60.0]
    @test m.ρ_min == 3.0

    m.δ_min = [3.0, 2.0]

    DS.SetRatioVector!(m)

    @test m.ρ == [3.0, 60.0]
    @test m.ρ_min == -Inf
end


@testset "decrease_a_and_b!" begin
    m = DS.AnisotropicMesh(5)
    m.a = [1.0, 1.0, 1.0, 2.0, 5.0]
    m.b = [3.0, -1.0, 0.0, 5.0, 5.0]
    m.δ_min = [1.0, 0.0, 1.0, 1.0, 1.0]

    expected_a = [5.0, 5.0, 1.0, 1.0, 2.0]
    expected_b = [2.0, -2.0, 0.0, 5.0, 5.0]
    @testset "i = $i" for i=1:5
        DS.decrease_a_and_b!(m, i)
        @test m.a[i] == expected_a[i]
        @test m.b[i] == expected_b[i]
    end
end

@testset "increase_a_and_b!" begin
    m = DS.AnisotropicMesh(5)
    m.a = [1.0, 2.0, 5.0, 2.0, 5.0]
    m.b = ones(5)

    DS.increase_a_and_b!(m, 1, nothing)

    @test m.a[1] == 2.0
    @test m.b[1] == 1.0

    DS.increase_a_and_b!(m, 2, nothing)

    @test m.a[2] == 5.0
    @test m.b[2] == 1.0

    DS.increase_a_and_b!(m, 3, nothing)

    @test m.a[3] == 1.0
    @test m.b[3] == 2.0

    m.is_anisotropic = true
    dir = ones(5)
    m.δ_min = [0.0, 0.0, 0.0, 1.0, 0.0]
    m.ρ = [1.0, 1.0, 1.0, 50.0, 1.0]

    DS.increase_a_and_b!(m, 4, dir)

    @test m.a[4] == 2.0
    @test m.b[4] == 1.0
end

@testset "MeshUpdate!" begin
    m = DS.AnisotropicMesh(2)
    m.δ_min = zeros(2)
    m.a⁰ = ones(2)
    m.b⁰ = zeros(2)

    @testset "Unsuccessful" begin
        m.a = [2.0, 5.0]
        m.b = [1.0, 2.0]
        m.l = 5

        DS.MeshUpdate!(m, LTMADS(), DS.Unsuccessful, nothing)

        @test m.a == [1.0, 2.0]
        @test m.b == [1.0, 2.0]
        @test m.δ == [1.0, 1.0]
        @test m.Δ == [10.0, 200.0]
        @test m.ρ == [10.0, 200.0]
        @test m.ρ_min == 10.0
    end

    @testset "Dominating" begin
        m.a = [2.0, 5.0]
        m.b = [1.0, 2.0]
        m.l = 5

        DS.MeshUpdate!(m, LTMADS(), DS.Dominating, nothing)

        @test m.a == [5.0, 1.0]
        @test m.b == [1.0, 3.0]
        @test m.δ == [1.0, 1.0]
        @test m.Δ == [50.0, 1000.0]
        @test m.ρ == [50.0, 1000.0]
        @test m.ρ_min == 50.0
    end
end

@testset "MeshSetup" begin
    p = DSProblem(3; granularity = [1.0, 0.1, 0.0], poll=UnitSpherePolling(3))

    DS.MeshSetup!(p)

    m = p.config.mesh
    @test m.is_anisotropic == true
    @test m.δ_min == [1.0, 0.1, 0.0]
    @test m.digits == [0, 1, nothing]
    @test m.only_granular == false
    @test m.l == 0
    @test m.a⁰ == [1.0, 1.0, 1.0]
    @test m.b⁰ == [0.0, 1.0, 0.0]
    @test m.a == [1.0, 1.0, 1.0]
    @test m.b == [0.0, 1.0, 0.0]
    @test m.δ == [1.0, 1.0, 1.0]
    @test m.Δ == [1.0, 1.0, 1.0]
    @test m.δ⁰ == [1.0, 1.0, 1.0]
end

@testset "init_a_and_b!" begin
    p = DSProblem(3; granularity = [1.0, 0.0, 2.0], initial_point=[1.0, 250.0, 9000.0])
    m = p.config.mesh
    m.δ_min = [1.0, 0.0, 2.0]

    DS.init_a_and_b!(p, m)

    @test m.a == [1, 2, 5]
    @test m.b == [0, 1, 2]
    @test m.a⁰ == [1, 2, 5]
    @test m.b⁰ == [0, 1, 2]
end
