# DirectSearch.jl

DirectSearch.jl implements several algorithms in the Mesh Adaptive Direct Search family and is designed to be easily modifiable but still high performance.

For details on the theory of the algorithms implemented here, please see:
- **MADS (and LTMADS)** : C.Audet and J.E. Dennis, "Mesh adaptive direct search algorithms for constrained optimization," *SIAM Journal on Optimization*, vol. 17, no. 1, pp. 188-217, 2007
- **Progressive Barrier MADS** : C.Audet and J.E. Dennis, "A progressive barrier for derivative-free nonlinear programming," *SIAM Journal on Optimization*, vol. 20, no. 1, pp. 445-472, 2009
- **OrthoMADS** : M. A. Abramson, C. Audet, J. E. Dennis, and S. Le Digabel, “Orthomads: A deterministic MADS instance with orthogonal directions,” *SIAM Journal on Optimization*, vol. 20, no. 2,pp. 948–966, 2009
- **MADS for granular variables** : C.  Audet,  S.  Le  Digabel,  and  C.  Tribes,  “The  mesh  adaptive  direct  search  algorithm  forgranular and discrete variables,” *SIAM Journal on Optimization*, vol. 29, pp. 1164–1189, 2019
