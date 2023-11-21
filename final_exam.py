from scipy.optimize import minimize
import numpy as np
import matplotlib.pyplot as plt

# Objective function to maximize (modify as needed)
def objective_function(variables):
    x1, x2, x3 = variables
    return ((x1*10-50000)*(x2*15-50000)*(x3*5-80000))  # Negative because we want to maximize

# Constraint: Sum of variables equals 100,000
def constraint_sum(variables):
    return sum(variables) - 100000

# Initial guess
initial_guess = [40000, 30000.0, 30000]

# Set up the optimization problem
optimization_result = minimize(
    fun=lambda x: -objective_function(x),  # Negative because we want to maximize
    method='trust-constr', # Use this method for adding constraint
    x0=initial_guess,
    constraints={'type': 'eq', 'fun': constraint_sum},
    bounds=[(0, 100000), (0, 100000), (0, 100000)]  # Non-negative bounds for variables
)

# Check result
if optimization_result.success:
    print("Optimize sucess")
    # fitted_params = optimization_result.x
    # print(fitted_params)
    # print(-optimization_result.fun)
else:
    raise ValueError(optimization_result.message)


# Extract the results
utility_nbs = -optimization_result.fun
print(utility_nbs)
optimal_x1 = round(optimization_result.x[0])
optimal_x2 = round(optimization_result.x[1])
optimal_x3 = round(optimization_result.x[2])
optimal_u1 = optimal_x1*10-50000
optimal_u2 = optimal_x2*15-50000
optimal_u3 = optimal_x3*5-80000
print(f"Optimal x1 = {optimal_x1}, Optimal u1 = {optimal_u1}")
print(f"Optimal x2 = {optimal_x2}, Optimal u2 = {optimal_u2}")
print(f"Optimal x3 = {optimal_x3}, Optimal u3 = {optimal_u3}")

# Define variables for ploting utility function
x_range = np.linspace(0, 100000, 100)
u1 = [x*10-50000 for x in x_range]
u2 = [x*15-50000 for x in x_range]
u3 = [x*5-80000 for x in x_range]

# Plot utility function for rich man
plt.plot(x_range, u1, label="Utility of Player 1, u1")
plt.plot(x_range, u2, label="Utility of Player 2, u2")
plt.plot(x_range, u3, label="Utility of Player 3, u3")
plt.scatter(optimal_x1, optimal_u1,  label="NBS point for player 1")
plt.scatter(optimal_x2, optimal_u2,  label="NBS point for player 2")
plt.scatter(optimal_x3, optimal_u3,  label="NBS point for player 3")
plt.xlabel('Amount of Money That Each Player Get')
plt.ylabel('Utility')
plt.title("Utility Functions")
plt.legend()
plt.show()