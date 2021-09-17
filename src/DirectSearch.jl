module DirectSearch

include("./Types.jl")
include("./Cache.jl")
include("./Constraints.jl")
include("./Core.jl")

# Mesh types
include( "./mesh/dispatching.jl" )
include( "./mesh/anisotropic.jl" )
include( "./mesh/isotropic.jl" )

# Search methods
include( "./search/search.jl" )
include( "./search/random.jl" )

# Polling methods
include( "./polling/poll.jl" )
include( "./polling/common.jl" )
include( "./polling/LTMADS.jl" )
include( "./polling/OrthoMADS.jl" )
include( "./polling/UnitSpherePolling.jl" )
#include("./GPS.jl")

# Stopping conditions
include( "./stopping/StoppingCondition.jl" )
include( "./stopping/iteration.jl" )
include( "./stopping/function.jl" )
include( "./stopping/runtime.jl" )
include( "./stopping/mesh.jl" )
include( "./stopping/poll.jl" )

include("./Report.jl")

include("./test_utils.jl")


end # module
