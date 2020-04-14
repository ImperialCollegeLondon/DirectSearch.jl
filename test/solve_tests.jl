@testset "Test Problems" begin
    @testset "Unconstrained" begin 
        @testset "camel6" begin
            p = DSProblem(2; objective=DS.camel6, initial_point=[5.0, 5.0])
            Optimize!(p)
            @test isapprox(abs(p.x[1]), 0.0898, atol=1e-4)
            @test isapprox(abs(p.x[2]), 0.7126, atol=1e-4) 
            @test isapprox(p.x_cost, -1.0316, atol=1e-4)
            @test p.iteration < 120
        end
        @testset "audet_dennis_benchmark_1" begin
            p = DSProblem(2; objective=DS.bm_1, initial_point=[-2.1, 1.7])
            Optimize!(p)
            @test isapprox(p.x[1], 0, atol=1e-8)
            @test isapprox(p.x[2], 0, atol=1e-8)
            @test isapprox(p.x_cost, 0, atol=1e-8)
            @test p.iteration < 120
        end
    end
    @testset "Extreme Constraints" begin
        @testset "camel6" begin
            p = DSProblem(2; objective=DS.camel6, initial_point=[5.0, 5.0])
            AddExtremeConstraint(p, x-> x[1] > 0)
            Optimize!(p)
            @test isapprox(p.x[1], 0.0898, atol=1e-4)
            @test isapprox(p.x[2], -0.7126, atol=1e-4) 
            @test isapprox(p.x_cost, -1.0316, atol=1e-4)
            @test p.iteration < 120

            p = DSProblem(2; objective=DS.camel6, initial_point=[-5.0, -5.0])
            AddExtremeConstraint(p, x->x[1] < 0)
            Optimize!(p)
            @test isapprox(p.x[1], -0.0898, atol=1e-4)
            @test isapprox(p.x[2], 0.7126, atol=1e-4) 
            @test isapprox(p.x_cost, -1.0316, atol=1e-4)
            @test p.iteration < 120
        end
    end
    @testset "Progressive Constraints" begin
        @testset "camel6" begin
            p = DSProblem(2; objective=DS.camel6, initial_point=[5.0, 5.0])
            AddProgressiveConstraint(p, x -> x[1])
            Optimize!(p)
            @test isapprox(p.x[1], -0.0898, atol=1e-4)
            @test isapprox(p.x[2], 0.7126, atol=1e-4) 
            @test isapprox(p.x_cost, -1.0316, atol=1e-4)
            @test p.iteration < 200

            p = DSProblem(2; objective=DS.camel6, initial_point=[-5.0, -5.0])
            AddProgressiveConstraint(p, x->-x[1])
            Optimize!(p)
            @test isapprox(p.x[1], 0.0898, atol=1e-4)
            @test isapprox(p.x[2], -0.7126, atol=1e-4) 
            @test isapprox(p.x_cost, -1.0316, atol=1e-4)
            @test p.iteration < 200
        end
        
        #@testset "audet_dennis_benchmark_3" begin
        #    #TODO update the constraints on result accuracy
        #    #as the package gives better results.
        #    N = 5
        #    p = DSProblem(5; objective=DS.bm_3, initial_point=zeros(5))
        #    AddProgressiveConstraint(p, DS.bm_3_con)
        #    Optimize!(p)
        #    @show p.x 
        #    @show p.i 
        #    for x in p.x
        #        @test isapprox(x, -√3, atol=1)
        #    end
        #    @test isapprox(p.x_cost, N * -√3, atol=0.5)
        #    @test p.iteration <= 1000
        #end
    end
end
