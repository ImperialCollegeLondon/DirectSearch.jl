using DirectSearch
using SafeTestsets
using Test

include("./test_Cache.jl")
include("./test_Search.jl")
include("./test_Constraints.jl")
include("./test_Core.jl")
include("./test_StoppingCondition.jl")
include("./test_Report.jl")
include("./solve_tests.jl") #temporary disabled until fixed

# Test the different methods for generating the poll directions
@testset "Polling Methods" begin
    @safetestset "Polling Common Functions" begin include( "./polling/test_pollCommon.jl" ) end
    @safetestset "Unit Sphere Polling" begin include( "./polling/test_UnitSpherePolling.jl" ) end
    @safetestset "OrthoMADS" begin include( "./polling/test_OrthoMADS.jl" ) end
    @safetestset "LTMADS" begin include( "./polling/test_LTMADS.jl" ) end
end

# Test the different mesh types
@testset "Mesh" begin
    @safetestset "Anisotropic Mesh" begin include( "./mesh/test_anisotropic.jl" ) end
end
