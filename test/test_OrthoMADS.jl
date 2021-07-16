using LinearAlgebra

@testset "OrthoMADS" begin
    @testset "Householder Transform" begin
        @test DS.HouseholderTransform([-1.0, 5.0, 6.0, -8.0]) ≈
											[124.0   10.0   12.0  -16.0;
											  10.0   76.0  -60.0   80.0;
											  12.0  -60.0   54.0   96.0;
											 -16.0   80.0   96.0   -2.0]
    end

    @testset "GenerateDirectionsOnUnitSphere" begin
        dirs = DS.GenerateDirectionsOnUnitSphere(3)
        @test norm(dirs) ≈ 1
        @test length(dirs) == 3 
    end
end

