using DirectSearch
using Test

const DS = DirectSearch

@testset "Householder Transform" begin
    @test DS._householder_transform([-1.0, 5.0, 6.0, -8.0]) ≈
                                        [124.0   10.0   12.0  -16.0;
                                          10.0   76.0  -60.0   80.0;
                                          12.0  -60.0   54.0   96.0;
                                         -16.0   80.0   96.0   -2.0]
end

@testset "Basis Formation" begin
    B = [ 4  0  0 -3  3;
          2  0 -4  2 -1;
          0  0  0  4  0;
          0  0  0 -1 -4;
         -2  4  0  0  1]

    minB = [ 4  0  0 -3  3 -4;
             2  0 -4  2 -1  1;
             0  0  0  4  0 -4;
             0  0  0 -1 -4  5;
            -2  4  0  0  1 -3]

    maxB = [ 4  0  0 -3  3 -4  0  0  3 -3;
             2  0 -4  2 -1 -2  0  4 -2  1;
             0  0  0  4  0  0  0  0 -4  0;
             0  0  0 -1 -4  0  0  0  1  4;
            -2  4  0  0  1  2 -4  0  0 -1]

    # Test maximal basis formation
    @test DS._form_basis_matrix( 5, B, true ) == maxB

    # Test minimal basis formation
    @test DS._form_basis_matrix( 5, B, false ) == minB
end
