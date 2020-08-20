@testset "Test Problems" begin
    @testset "Unconstrained" begin
        @testset "camel6" begin
            p = DSProblem(2; poll=OrthoMADS(), objective=DS.camel6, initial_point=[5.0, 5.0])
            Optimize!(p)
            @test isapprox(abs(p.x[1]), 0.0898, atol=1e-4)
            @test isapprox(abs(p.x[2]), 0.7126, atol=1e-4)
            @test isapprox(p.x_cost, -1.0316, atol=1e-4)
            @test p.status.iteration < 120
        end
        @testset "audet_dennis_benchmark_1" begin
            p = DSProblem(2; poll=OrthoMADS(), objective=DS.bm_1, initial_point=[-2.1, 1.7])
            Optimize!(p)
            @test isapprox(p.x[1], 0, atol=1e-8)
            @test isapprox(p.x[2], 0, atol=1e-8)
            @test isapprox(p.x_cost, 0, atol=1e-8)
            @test p.status.iteration < 120
        end
    end
    @testset "Extreme Constraints" begin
        #@testset "camel6" begin
        #    p = DSProblem(2; poll=OrthoMADS(), objective=DS.camel6, initial_point=[5.0, 5.0])
        #    AddExtremeConstraint(p, x-> x[1] > 0)
        #    Optimize!(p)
        #    @test isapprox(p.x[1], 0.0898, atol=1e-4)
        #    @test isapprox(p.x[2], -0.7126, atol=1e-4)
        #    @test isapprox(p.x_cost, -1.0316, atol=1e-4)
        #    @test p.status.iteration < 120

        #    p = DSProblem(2; poll=OrthoMADS(), objective=DS.camel6, initial_point=[-5.0, -5.0])
        #    AddExtremeConstraint(p, x->x[1] < 0)
        #    Optimize!(p)
        #    @test isapprox(p.x[1], -0.0898, atol=1e-4)
        #    @test isapprox(p.x[2], 0.7126, atol=1e-4)
        #    @test isapprox(p.x_cost, -1.0316, atol=1e-4)
        #    @test p.status.iteration < 120
        #end
    end
    @testset "Progressive Constraints" begin
        #Progressive barrier constraints struggle to converge with LTMADS, therefore use OrthoMADS
        @testset "camel6" begin
            p = DSProblem(2; poll=OrthoMADS(), objective=DS.camel6, initial_point=[5.0, 5.0])
            AddProgressiveConstraint(p, x -> x[1])
            Optimize!(p)
            @test isapprox(p.x[1], -0.0898, atol=1e-4)
            @test isapprox(p.x[2], 0.7126, atol=1e-4)
            @test isapprox(p.x_cost, -1.0316, atol=1e-4)
            @test p.status.iteration < 200

            p = DSProblem(2; poll=OrthoMADS(), objective=DS.camel6, initial_point=[-5.0, -5.0])
            AddProgressiveConstraint(p, x->-x[1])
            Optimize!(p)
            @test isapprox(p.x[1], 0.0898, atol=1e-4)
            @test isapprox(p.x[2], -0.7126, atol=1e-4)
            @test isapprox(p.x_cost, -1.0316, atol=1e-4)
            @test p.status.iteration < 200
        end
    end
end
