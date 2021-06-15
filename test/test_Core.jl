@testset "Core" begin
    T = Float64
    @testset "DSProblem" begin
        N = 3
        p = DSProblem{T}(N)
        @test p.N == N
        @test typeof(p.config.search) == NullSearch
        @test typeof(p.config.poll) == LTMADS{T}
        @test p.status.optimization_status == DS.Unoptimized
        @test p.status.optimization_status_string == "Unoptimized"
        @test p.sense == DS.Min
        @test p.config.max_simultaneous_evaluations == 1
        @test typeof(p.config.mesh) == DS.Mesh{T}

        @test typeof(p.cache) == DS.PointCache{T}
        @test isempty(p.cache.costs)
        @test isempty(p.cache.order)

        @test typeof(p.constraints) == DS.Constraints{T}
    end

    @testset "Mesh" begin
        N = 3
        p = DSProblem{T}(N)
        m = DS.Mesh{T}(N)
        @test p.config.mesh.G == m.G == [1 0 0; 0 1 0; 0 0 1]
        @test p.config.mesh.D == m.D == [1 0 0 -1 0 0; 0 1 0 0 -1 0; 0 0 1 0 0 -1]
        @test p.config.mesh.Δᵐ == m.Δᵐ == 1.0
        # More rigourous tests for MeshUpdate! are in test_LTMADS etc.
        DS.MeshUpdate!(p, DS.Unsuccessful)
        @test p.config.mesh.Δᵐ == 0.25
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
        @test p.stoppingconditions[1].limit == 1000
        @test p.status.iteration == 0

        Optimize!(p)

        @test p.status.iteration == 1000
        @test_throws ErrorException SetIterationLimit(p, 900)
        SetIterationLimit(p, 1100)
        @test p.stoppingconditions[1].limit == 1100
        BumpIterationLimit(p, 200)
        @test p.stoppingconditions[1].limit == 1300

        # Variable Ranges
        p = DSProblem{T}(3)
        @test p.config.meshscale == [1.0, 1.0, 1.0]
        @test_throws ErrorException SetVariableRange(p, 4, -5.0, 5.0)
        SetVariableRange(p, 3, -5.0, 5.0)
        @test p.config.meshscale == [1.0, 1.0, 1.0]
        SetVariableRange(p, 3, -10.0, 10.0)
        @test p.config.meshscale == [1.0, 1.0, 2.0]

        @test_throws ErrorException SetVariableRanges(p, [-5.0, -5.0, -5.0, -5.0], [5.0, 5.0, 5.0, 5.0])
        SetVariableRanges(p, [-5.0, -5.0, -5.0], [5.0, 5.0, 5.0])
        @test p.config.meshscale == [1.0, 1.0, 1.0]
        SetVariableRanges(p, [-10.0, -10.0, -10.0], [10.0, 10.0, 10.0])
        @test p.config.meshscale == [2.0, 2.0, 2.0]

        # Sense
        p = DSProblem{T}(3)
        @test p.sense == DS.Min
        p = DSProblem{T}(3, sense=DS.Min)
        @test p.sense == DS.Min
        p = DSProblem{T}(3, sense=DS.Max)
        @test p.sense == DS.Max

        p = DSProblem{T}(3)
        SetSense(p, DS.Max)
        @test p.sense == DS.Max
        SetSense(p, DS.Min)
        @test p.sense == DS.Min
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

    @testset "Opportunistic Evaluation" begin
        #Initialisation
        p = DSProblem(3)
        @test p.config.opportunistic == false

        p = DSProblem(3, opportunistic=false)
        @test p.config.opportunistic == false

        p = DSProblem(3, opportunistic=true)
        @test p.config.opportunistic == true

        #Setter
        p = DSProblem(3)
        @test p.config.opportunistic == false
        SetOpportunisticEvaluation(p)
        @test p.config.opportunistic == true
        SetOpportunisticEvaluation(p, opportunistic=true)
        @test p.config.opportunistic == true
        SetOpportunisticEvaluation(p, opportunistic=false)
        @test p.config.opportunistic == false

        #Efficacy

        #Confirm that all points are checked and best is taken
        p = DSProblem(3; objective=x->sum(x.^2), initial_point=[10, 10, 10])
        SetIterationLimit(p, 1000) #Needed for setup to run
        DS.Setup(p)
        SetOpportunisticEvaluation(p, opportunistic=false)
        @test p.x == [10.0, 10.0, 10.0]
        DS.EvaluatePoint!(p, [[9.0,9.0,9.0], [8.0,8.0,8.0], [5.0,5.0,5.0], [11.0,11.0,11.0]])
        @test p.x == [5.0,5.0,5.0]

        p = DSProblem(3; objective=x->sum(x.^2), initial_point=[10, 10, 10])
        SetIterationLimit(p, 1000) #Needed for setup to run
        DS.Setup(p)
        SetOpportunisticEvaluation(p, opportunistic=true)
        @test p.x == [10.0, 10.0, 10.0]
        DS.EvaluatePoint!(p, [[9.0,9.0,9.0], [8.0,8.0,8.0], [5.0,5.0,5.0], [11.0,11.0,11.0]])
        @test p.x == [9.0,9.0,9.0]
    end
end
