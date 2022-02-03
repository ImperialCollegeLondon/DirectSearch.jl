using Random

@testset "Core" begin
    T = Float64
    @testset "DSProblem" begin
        N = 3
        p = DSProblem{T}(N)
        @test p.N == N
        @test typeof(p.config.search) == NullSearch
        @test typeof(p.config.poll) == UnitSpherePolling{typeof( Random.default_rng() )}
        @test p.status.optimization_status == DS.Unoptimized
        @test p.status.optimization_status_string == "Unoptimized"
        @test p.sense == DS.Min
        @test p.config.max_simultaneous_evaluations == 1
        @test typeof(p.config.mesh) == DS.AnisotropicMesh{T}

        @test typeof(p.cache) == DS.PointCache{T}
        @test isempty(p.cache.costs)
        @test isempty(p.cache.order)

        @test typeof(p.constraints) == DS.Constraints{T}
    end

    @testset "Setters" begin
        test_point = [1, 0.3]
        test_out = 49
        p = DSProblem{T}(2)
        f = DS.rosenbrock

        @testset "SetObjective" begin
            @test !isdefined(p, :objective)
            SetObjective(p, f)
            @test isdefined(p, :objective)
            @test p.objective(test_point) ≈ test_out

            p = DSProblem{T}(2, sense=DS.Max)
            SetObjective(p, f)
            @test p.objective(test_point) ≈ -test_out
        end


        @testset "SetInitialPoint" begin
            @test_throws ErrorException SetInitialPoint(p, [1.0, 1.0, 1.0])
            @test_throws ErrorException SetInitialPoint(p, [1.0])
            SetInitialPoint(p, [5.0, 5.0])
            @test p.user_initial_point == [5.0, 5.0]
        end

        @testset "SetVariableBound" begin
            p = DSProblem{T}(3)
            @test_throws ErrorException SetVariableBound(p, 4, -5.0, 5.0)
            SetVariableBound(p, 3, -5.0, 5.0)
            @test p.lower_bounds == [nothing, nothing, -5.0]
            @test p.upper_bounds == [nothing, nothing, 5.0]
            SetVariableBound(p, 3, -10.0, 10.0)
            @test p.lower_bounds == [nothing, nothing, -10.0]
            @test p.upper_bounds == [nothing, nothing, 10.0]
        end

        @testset "SetVariableBounds" begin
            p = DSProblem{T}(3)
            @test_throws ErrorException SetVariableBounds(p, [-5.0, -5.0, -5.0, -5.0], [5.0, 5.0, 5.0, 5.0])
            SetVariableBounds(p, [-5.0, -5.0, -5.0], [5.0, 5.0, 5.0])
            @test p.lower_bounds == [-5.0, -5.0, -5.0]
            @test p.upper_bounds == [5.0, 5.0, 5.0]
            SetVariableBounds(p, [-10.0, -10.0, -10.0], [10.0, 10.0, 10.0])
            @test p.lower_bounds == [-10.0, -10.0, -10.0]
            @test p.upper_bounds == [10.0, 10.0, 10.0]
        end

        @testset "SetMaxEvals" begin
            p = DSProblem(3)
            p.config.num_threads = 5
            SetMaxEvals(p)
            @test p.config.max_simultaneous_evaluations == 5
            SetMaxEvals(p, false)
            @test p.config.max_simultaneous_evaluations == 1
        end

        @testset "SetFullOutput" begin
            p = DSProblem{T}(3)
            SetFullOutput(p)
            @test p.full_output
            SetFullOutput(p, false)
            @test !p.full_output
        end

        @testset "SetOpportunisticEvaluation" begin
            p = DSProblem{T}(3)
            SetOpportunisticEvaluation(p)
            @test p.config.opportunistic
            SetOpportunisticEvaluation(p, opportunistic=false)
            @test !p.config.opportunistic
        end

        @testset "SetSense" begin
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

        @testset "SetGranularity" begin
            p = DSProblem{T}(3)
            @test_throws ErrorException SetGranularity(p, 4, 3.0)
            @test_throws ErrorException SetGranularity(p, 2, -3.0)
            SetGranularity(p, 2, 3.0)
            @test p.granularity == [0.0, 3.0, 0.0]
        end

        @testset "SetGranularities" begin
            p = DSProblem{T}(3)
            @test_throws ErrorException SetGranularities(p, [1.0, 2.0, 3.0, 4.0])
            SetGranularities(p, [1.0, 2.0, 3.0])
            @test p.granularity == [1.0, 2.0, 3.0]
        end
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

    @testset "Granular problem" begin
        # Should not warn
        p = DSProblem(3; objective=x->sum(x.^2), initial_point=[0.3, 0.1, 1.0])
        SetGranularities( p, [0.1; 0.1; 0.1] )
        SetIterationLimit(p, 1000) #Needed for setup to run
        DS.Setup(p)

        # Should warn on the setup that the initial point's 1st element isn't on the grid
        p = DSProblem(3; objective=x->sum(x.^2), initial_point=[0.25, 0.1, 1.0])
        SetGranularities( p, [0.1; 0.1; 0.1] )
        SetIterationLimit(p, 1000) #Needed for setup to run
        @test_logs (:warn, "Initial point element 1 is not of the specified granularity. Rounding 0.25 to 0.2.") DS.Setup(p)
    end
end
