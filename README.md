# DirectSearch.jl
<!-- Currently isn't a stable release -->
<!--[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://EdwardStables.github.io/DirectSearch.jl/stable)-->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://EdwardStables.github.io/DirectSearch.jl/dev)
[![Build Status](https://travis-ci.com/EdwardStables/DirectSearch.jl.svg?branch=master)](https://travis-ci.com/EdwardStables/DirectSearch.jl)


This is a package that implements several direct search derivative-free optimization algorithms. Currently the LTMADS algorithm for unconstrained problems is supported, as well a progressive and extreme barrier constraints. In the near future OrthoMADS will also be implemented.

This package is designed to offer a flexible framework for implementing variations and extensions to these algorithms. For example, a new method for selecting search directions can be defined with the implemention of a single type and function. The constraint definitions are also flexible, constraints can be grouped together, with each group given their own set of parameters (e.g. update functions for progressive barrier).

All evaluated points are cached to avoid repeated calculation.

Examples will be added as the package becomes more mature and tested, it is currently at an early stage.
