@testset "StoppingCondition" begin 

    @testset "Defaults" begin
        p = DSProblem(4)
        @test typeof(p.stoppingconditions[1]) == DS.IterationStoppingCondition
        @test typeof(p.stoppingconditions[2]) == DS.FunctionEvaluationStoppingCondition
        @test typeof(p.stoppingconditions[3]) == DS.MeshPrecisionStoppingCondition{AnisotropicMesh{Float64},Float64}
        @test typeof(p.stoppingconditions[4]) == DS.PollPrecisionStoppingCondition{Float64}

        @test p.stoppingconditions[1].limit == 1000
        @test p.stoppingconditions[2].limit == 5000

        p = DSProblem(4; iteration_limit=100, function_evaluation_limit=500)
        @test p.stoppingconditions[1].limit == 100
        @test p.stoppingconditions[2].limit == 500
    end

    @testset "AddStoppingCondition" begin
        p = DSProblem(4)
        
        test_stopping_cond = DS.RuntimeStoppingCondition(1234)
        DS.AddStoppingCondition(p, test_stopping_cond)
        @test p.stoppingconditions[5].limit == 1234
    end

    @testset "_check_stoppingconditions" begin
        p = DSProblem(4)
        c = DS.AbstractStoppingCondition[]
        @test DS._check_stoppingconditions(p, c) == true

        p.status.iteration = 100
        push!(c, DS.IterationStoppingCondition(200))
        @test DS._check_stoppingconditions(p, c) == true

        p.status.iteration = 200
        @test DS._check_stoppingconditions(p, c) == false

        p.status.iteration = 300
        @test DS._check_stoppingconditions(p, c) == false


        push!(c, DS.IterationStoppingCondition(400))
        @test DS._check_stoppingconditions(p, c) == false
    end

    @testset "setstatus" begin
        p = DSProblem(4)

        @test p.status.optimization_status == DS.Unoptimized
        @test p.status.optimization_status_string == "Unoptimized"
 
        struct test_sc <: DS.AbstractStoppingCondition end
        DS.StoppingConditionStatus(::test_sc) = "test status message"
        DS.CheckStoppingCondition(p::DSProblem, s::test_sc) = false

        DS.setstatus(p, test_sc())
        @test p.status.optimization_status_string == "test status message"

        DS.MeshSetup!(p)
        DS._init_stoppingconditions(p)

        #First false sc reached in the array is the reported status 
        DS.AddStoppingCondition(p, test_sc())
        @test DS._check_stoppingconditions(p) == false
        @test p.status.optimization_status_string == "test status message"
        p.status.iteration = 1001
        @test DS._check_stoppingconditions(p) == false
        @test p.status.optimization_status_string == "Iteration limit"
    end

    @testset "StoppingConditionStatus" begin
        struct another_test_sc <: DS.AbstractStoppingCondition end
        DS.CheckStoppingCondition(p::DSProblem, s::another_test_sc) = false

        stop_cond = another_test_sc()

        @test DS.StoppingConditionStatus(stop_cond) == "Unknown stopping condition status"
        p = DSProblem(4)
        DS.AddStoppingCondition(p, stop_cond)

        DS.MeshSetup!(p)
        DS._init_stoppingconditions(p)

        DS._check_stoppingconditions(p)
        @test p.status.optimization_status == DS.OtherStoppingCondition
        @test p.status.optimization_status_string == "Unknown stopping condition status"
    end

end
