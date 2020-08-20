# Create an inf value in a given float type
inf(::Type{Float64}) = Inf64
inf(::Type{Float32}) = Inf32
inf(::Type{Float16}) = Inf16
