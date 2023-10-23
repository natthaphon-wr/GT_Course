import numpy as np
import math
import matplotlib.pyplot as plt
from scipy.optimize import minimize

# Define the optimize function: modify Maximum NBS to minizing
def objective_function(x1):
    return -(50*math.log10(1+x1)-100)*(100*math.log10(1+100000-x1)-50)

# Use the minimize function to get result
result = minimize(objective_function, 0)

# Extract and determine result
utility_nbs = -result.fun
optimal_x1 = round(result.x[0])
optimal_x2 = 100000-optimal_x1
optimal_u1 = 50*math.log10(1+optimal_x1)-100
optimal_u2 = 100*math.log10(1+100000-optimal_x1)-100

# Define variables for ploting utility function
x1_range = np.linspace(0, 100000, 100)
objective_values = [-objective_function(x) for x in x1_range]
u1 = [(50*math.log10(1+x)-100) for x in x1_range]
u2 = [(100*math.log10(1+100000-x)-100) for x in x1_range]

# Plot utility function for rich man
plt.plot(x1_range, u1, label="Utility of Rich Man (U1)")
plt.plot(100000-x1_range, u2, label="Utility of Poor Man (U2)"),
plt.xlabel('Amount of Money That Each Man Get')
plt.ylabel('Utility')
plt.title("Utility Functions of Both Men")
plt.legend()
plt.show()

# Plot utility function
plt.plot(u1, u2, label="Utility Function")
plt.scatter(optimal_u1, optimal_u2, color='red', label="NBS outcome")
plt.xlabel('Utility of Rich Man (U1)')
plt.ylabel('Utility of Poor Man (U2)')
plt.title("Utility Functions and NBS Outcome")
plt.text(optimal_u1-90, optimal_u2-15, s=f"U1*={round(optimal_u1,2)} and U2*={round(optimal_u2,2)} with X1={optimal_x1} USD", 
         color='red', fontsize='medium', fontstyle='italic')
plt.legend()
plt.show()