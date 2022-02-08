# This file contains functions for dispatching to mesh-related functions using only the
# problem and other associated data

"""
    MeshSetup!(p::DSProblem)

Set up the mesh with the parameters defined for problem.
"""
MeshSetup!(p::DSProblem) = MeshSetup!(p, p.config.mesh)


"""
    MeshUpdate!(p::DSProblem, result::IterationOutcome)

Update the mesh in `p` based on the outcome of the most recent iteration.
"""
MeshUpdate!(p::DSProblem, result::IterationOutcome) =
    MeshUpdate!(p.config.mesh, p.config.poll, result, p.status.success_direction)
