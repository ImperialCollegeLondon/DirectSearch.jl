module DirectSearch


include("./Types.jl")
include("./Cache.jl")
include("./Constraints.jl")
include("./Core.jl")
include("./Mesh.jl")
include("./Search.jl")
include("./Poll.jl")
include("./Report.jl")

#Include preset methods here
include("./LTMADS.jl")
include("./OrthoMADS.jl")
#include("./GPS.jl")

include("./test_utils.jl")


end # module
