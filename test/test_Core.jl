@testset "Core" begin
    T = Float64
    @testset "DSProblem" begin
        N = 3
        p = DSProblem{T}(N)
        @test p.N == N
        @test typeof(p.search) == NullSearch
        @test typeof(p.poll) == LTMADS{T}
        @test p.status == DS.Unoptimized
        @test p.sense == DS.Min
        @test p.max_simultanious_evaluations == 1
        @test typeof(p.mesh) == DS.Mesh{T}

        @test typeof(p.cache) == DS.PointCache{T}
        @test isempty(p.cache.costs)
        @test isempty(p.cache.order)

        @test typeof(p.constraints) == DS.Constraints{T}
    end

    @testset "Mesh" begin
        N = 3
        p = DSProblem{T}(N)
        m = DS.Mesh{T}(N)
        @test p.mesh.G == m.G == [1 0 0; 0 1 0; 0 0 1]
        @test p.mesh.D == m.D == [1 0 0 -1 0 0; 0 1 0 0 -1 0; 0 0 1 0 0 -1]
        @test p.mesh.Δᵐ == m.Δᵐ == 1.0
        # More rigourous tests for MeshUpdate! are in test_LTMADS etc.
        DS.MeshUpdate!(p, DS.Unsuccessful)
        @test p.mesh.Δᵐ == 0.25
    end

    @testset "min_mesh_size" begin
        N = 3
        p = DSProblem{Float64}(N)
        @test DS.min_mesh_size(p) ≈ 1.1102230246251565e-16
    end

    @testset "max_evals" begin
        #This will likely be changing, so don't bother test yet
    end
    
    @testset "Setters" begin
        test_point = [1, 0.3]
        test_out = 49
        p = DSProblem{T}(2)
        f = DS.rosenbrock
        
        # SetObjective
        @test !isdefined(p, :objective)
        SetObjective(p, f)
        @test isdefined(p, :objective)
        @test p.objective(test_point) ≈ test_out

        p = DSProblem{T}(2, sense=DS.Max)
        SetObjective(p, f)
        @test p.objective(test_point) ≈ -test_out


        # SetInitialPoint
        @test_throws ErrorException SetInitialPoint(p, [1.0, 1.0, 1.0])
        @test_throws ErrorException SetInitialPoint(p, [1.0])
        SetInitialPoint(p, [5.0, 5.0])
        @test p.user_initial_point == [5.0, 5.0]

        # Iteration limits
        @test p.iteration_limit == 1000
        @test p.iteration == 0

        Optimize!(p)

        @test p.iteration == 1000
        @test_throws ErrorException SetIterationLimit(p, 900)
        SetIterationLimit(p, 1100)
        @test p.iteration_limit == 1100
        BumpIterationLimit(p) 
        @test p.iteration_limit == 1200
        BumpIterationLimit(p; i=200) 
        @test p.iteration_limit == 1400

        # Variable Ranges
        p = DSProblem{T}(3)
        @test p.meshscale == [1.0, 1.0, 1.0]
        @test_throws ErrorException SetVariableRange(p, 4, -5.0, 5.0)
        SetVariableRange(p, 3, -5.0, 5.0)
        @test p.meshscale == [1.0, 1.0, 1.0]
        SetVariableRange(p, 3, -10.0, 10.0)
        @test p.meshscale == [1.0, 1.0, 2.0]

        @test_throws ErrorException SetVariableRanges(p, [-5.0, -5.0, -5.0, -5.0], [5.0, 5.0, 5.0, 5.0])
        SetVariableRanges(p, [-5.0, -5.0, -5.0], [5.0, 5.0, 5.0])
        @test p.meshscale == [1.0, 1.0, 1.0]
        SetVariableRanges(p, [-10.0, -10.0, -10.0], [10.0, 10.0, 10.0])
        @test p.meshscale == [2.0, 2.0, 2.0]
    end

    @testset "Optimize!" begin
    # TODO need to think about how to test this properly.
    # It is run several times during testing, so if it is broken then it should come up,
    # but it should still be tested.
    end

    @testset "EvaluatePoint!" begin
        function setup(con; initial=[4.0, 4.0, 4.0])
            p = DSProblem{T}(3)
            f = DS.rosenbrock
            SetObjective(p, f)
            SetInitialPoint(p, initial)
            con(p)
            DS.EvaluateInitialPoint(p)
            return p
        end
        p = setup(x->Nothing)
        # empty
        @test DS.EvaluatePoint!(p, []) == DS.Unsuccessful
        # Extreme constraints
        AddExtremeConstraint(p, x->x[1] > 0)
        @test DS.EvaluatePoint!(p, [[3.0, 3.0, 3.0]]) == DS.Dominating
        @test DS.EvaluatePoint!(p, [[-1.0, 3.0, 3.0]]) == DS.Unsuccessful

        p = setup(p->AddExtremeConstraint(p, x->x[1] > 0))
        @test DS.EvaluatePoint!(p, [[3.0, 3.0, 3.0],[-1.0, 3.0, 3.0]]) == DS.Dominating

        # Progressive Constraints
        
        #Feasible point with cost reduction is dominating
        p = setup(p->AddProgressiveConstraint(p, x->x[1] > 0 ? 0 : -x[1]))
        @test DS.EvaluatePoint!(p, [[3.0, 3.0, 3.0]]) == DS.Dominating

        #Feasible point with cost increase is unsuccessful
        p = setup(p->AddProgressiveConstraint(p, x->x[1] > 0 ? 0 : -x[1]))
        @test DS.EvaluatePoint!(p, [[5.0, 4.0, 4.0]]) == DS.Unsuccessful

        #Infeasible point with worse cost but less violation is improving
        p = setup(p->AddProgressiveConstraint(p, x->-x[1]), initial=[-6.0, 4.0, 4.0])
        @test DS.EvaluatePoint!(p, [[-5.0, 11.0, 4.0]]) == DS.Improving

        #Infeasible point with improving cost and less violation is dominating 
        p = setup(p->AddProgressiveConstraint(p, x->x[1] > 0 ? 0 : -x[1]))
        @test DS.EvaluatePoint!(p, [[-1.0, 4.0, 4.0]]) == DS.Dominating

        #Infeasible point with improving cost and greater violation is unsuccessful
        p = setup(p->AddProgressiveConstraint(p, x->x[1] > 0 ? 0 : -x[1]))
        p.constraints.collections[2].h_max = -4.0
        @test DS.EvaluatePoint!(p, [[-1.0, 4.0, 4.0]]) == DS.Unsuccessful
    end
end
