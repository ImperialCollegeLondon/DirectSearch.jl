export DS, run_lt_test
const DS = DirectSearch


#= Following functions sourced from https://www.sfu.ca/~ssurjano/optimization.html =#
#Valley
#soln: -1.0316 @ [±0.0898, ∓0.7126]
camel6(x)=(4-2.1x[1]^2 + x[1]^4/3)x[1]^2 + x[1]x[2] + (-4 + 4x[2]^2)x[2]^2
#soln: 0 @ [1,...,1]
rosenbrock(x;a=1,b=100,d=length(x)) = sum([b*(x[i+1] - x[i]^2)^2 + (x[i]-a)^2 for i=1:d-1])

#Local Minima
ackley(x;a=20,b=0.2,c=2pi,d=length(x)) = -a * exp(-b*√(sum(x.^2)/d)) - exp(sum(cos.(c.*x))/d) + a + exp(1)
eggholde(rx) = -(x[2]+47)sin(√abs(x[2] + x[1]/2 + 47)) - x[1]sin(√abs(x[1]-x[2]+47))

#Example Benchmarks from papers
#Audet & Dennis 2006 benchmark one, take x₀=[-2.1,1.7]
#soln: 0 @ [0,0]
bm_1(x;c=[30;40],d=[-30;-40]) = (1-exp(-norm(x)^2)) * max(norm(x-c)^2, norm(x-d)^2)

#Audet & Dennis 2006 benchmark three, should take x₀=[0,...,0]
#soln: -√(3)n @ [-√3,...,-√3]
bm_3(x)=sum(x)
bm_3_con(x)=sum(x.^2)-3*length(x)

function run_lt_test(;f=camel6,n=2,
                     constraints::Vector=[],
                     initial=zeros(Float64,n),
                     lim=1000,
                     lb=-5*ones(Float64,n), 
                     ub=5*ones(Float64,n),
                     run=true)
    p = DSProblem(n)
    SetObjective(p, f)
    SetInitialPoint(p, initial)
    SetMaxEvals(p, 1)
    for c in constraints
        AddExtremeConstraint(p, c)
    end
    p.iteration_limit = lim
    SetVariableRanges(p, lb, ub)
    if run
        DS.Optimize!(p)
        println("$(p.iteration)\t$(p.x)\t$(p.x_cost)")
    end
    return p
end

