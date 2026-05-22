# MathCLI iOS App Guide

This guide explains how to use the MathCLI iOS app, how to move through the main screens, and what commands are available by default.

## App Layout

MathCLI has four main tabs:

- Calculator: the primary working area for entering commands and expressions.
- History: session history, bookmarks, search, session export, and session cleanup.
- Operations: browsable reference for built-in command categories.
- Settings: theme, calculator text, app-data import/export, and destructive maintenance actions.

The app is designed around sessions. A session contains the commands you run, their results, bookmarks, variables, and the current `ans`/`$` value. You can create separate sessions for separate problems, switch between them, rename them, and close sessions you no longer need.

## Calculator Tab

The Calculator tab is the main workspace.

### Session Tabs

Session tabs sit above the terminal-style history. Use them to switch between active sessions. The `+` button creates a new session. Existing session controls support rename, switching, and closing.

Use separate sessions when you want different variables or histories for different work. For example, keep one session for a statistics problem and another for unit conversions.

### Command History

The history area shows:

- A timestamp for each command and result.
- The command you entered.
- The result, error, or informational message returned by the app.

The output is terminal-like by design. Commands are shown with a prompt marker. Results are shown directly underneath.

### Input Box

The input box accepts both command syntax and expression syntax.

Command syntax:

```text
add 5 10
mean 4 8 15 16 23 42
area_rectangle 12 8
```

Expression syntax:

```text
7 + 9 * 2
(7 + 9) * 2
sqrt(16) + sin(0)
```

MathCLI detects expression input when it sees ordinary math operators, parentheses, commas, or a single numeric/variable reference.

### Command Suggestions

When you start typing a command name, suggestions appear above the input. Tap a suggestion to complete the command. Suggestions are based on registered operation names.

### Quick Command Bar

The quick command bar starts with these default commands:

- `add`
- `subtract`
- `multiply`
- `divide`
- `power`

Tap a command button to insert that command into the input box. The bar is customizable from the Command Drawer.

### Command Drawer

Open the Command Drawer from the grid/browse button in the command bar. The drawer lets you:

- Browse commands by category.
- Search command names.
- Tap a command card to open help, including parameters.
- Tap `Use` to insert a command into the input box.
- Pin or unpin commands on the quick command bar.
- Reset pinned commands to the defaults.

The drawer is scrollable. It opens large by default, and its content scrolls independently from the sheet.

### Calculator And Scientific Drawers

Use the keyboard menu to switch input panels:

- Command Bar: compact pinned commands and browse access.
- Calculator: standard calculator keys.
- Scientific: scientific functions, constants, and calculator keys.

Calculator and Scientific panels have a drag handle. Pull the handle up or down to resize the drawer. Buttons shrink within a readable range; if the panel becomes too short for all keys, the key grid scrolls.

## Input Reference

### Commands

Command input follows this shape:

```text
command_name argument1 argument2
```

Examples:

```text
add 5 10
divide 100 4
std_dev 4 8 15 16 23 42
```

Arguments are separated by spaces. Quoted strings are supported for string-like arguments where a command accepts them.

### Expressions

Expression input supports:

- `+`, `-`, `*`, `/`
- Calculator multiply/divide keys insert `*` and `/` into the expression.
- `%` modulo
- `^` exponentiation
- `!` factorial
- Parentheses
- Comma-separated function arguments
- Unary plus/minus
- Numeric constants: `pi`, `e`, `tau`
- Variables by name, `$name`, `$`, or `ans`

Examples:

```text
7 + 9 * 2
(7 + 9) * 2
2 ^ 8
5!
sqrt(16)
pow(2, 8)
max(4, 8, 15, 16, 23, 42)
```

Expression functions include common scientific functions such as `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `sqrt`, `cbrt`, `abs`, `ln`, `log`, `log10`, `exp`, `floor`, `ceil`, `round`, `trunc`, `to_radians`, `to_degrees`, `pow`, `power`, `min`, `max`, `mean`, `avg`, and `average`. Numeric built-in commands and user-defined functions can also be called as expression functions when their return value is numeric.

### Previous Result

After each successful command or expression, MathCLI stores the result as both:

- `$`
- `ans`

Examples:

```text
add 72 120
multiply $ 3
ans / 2
```

### Variables

Use `set` to store variables:

```text
set x 42
set y 7 + 9
```

Use `$name` in command syntax:

```text
multiply $x 2
```

Use `name` or `$name` in expression syntax:

```text
x + 8
$y * 3
```

Use `vars` to list variables, `get name` to inspect one variable, `unset name` to delete one, and `clear_vars` to clear all variables.

### Assignment Shortcut

Expression assignment is supported:

```text
radius = 12
area = pi * radius ^ 2
```

This stores the result in the named variable and returns the value.

### Chained Commands

Use `|` to pass the previous step's result into the next command as the first argument.

```text
add 7 2 | multiply 4 | subtract 6
```

This is equivalent to:

```text
add 7 2
multiply 9 4
subtract 36 6
```

### User Functions

Define a function with `def`, list functions with `funcs`, and remove one with `undef`.

```text
def double x = multiply $x 2
double 21
funcs
undef double
```

Function bodies can call existing commands. Expression function calls can use user-defined functions when they return numeric values.

## History Tab

Use History to review and manage work after it has been run.

Supported actions:

- View active and previous sessions.
- Search commands and results.
- Bookmark important entries.
- Delete entries or sessions.
- Export the current session.
- Export all sessions.
- Choose JSON or Markdown export paths.

Destructive actions require confirmation before they run.

## Operations Tab

Operations is the in-app reference. It shows command categories and operation detail help. Use it when you want to discover commands without opening the Command Drawer from Calculator.

The Command Drawer is better when you want to insert or pin a command immediately. The Operations tab is better when you want to browse the whole catalog.

## Settings Tab

Settings controls app-level preferences and data maintenance.

Supported settings include:

- Theme selection.
- Calculator text font.
- Calculator text color.
- App data export.
- App data import.
- Clear variables.
- Clear functions.

Themes affect app surfaces and calculator text. Font and color controls apply to calculator/function text in the terminal-style calculator area and keypad text where applicable.

Import/export uses iOS file flows. App-data export includes sessions, variables, and user-defined functions.

Destructive clear actions require confirmation.

## Export And Import

History exports are session-focused. Settings exports are app-data focused.

Session export includes:

- Export version.
- Export timestamp.
- Session id, name, created timestamp, and active flag.
- Commands, results, timestamps, bookmark flags, and bookmark names.

Settings app-data export includes:

- Session snapshots.
- Variables.
- User-defined functions.

## Current Boundaries

- The app is iOS/iPadOS only.
- Simulator-ready development is supported without Apple device provisioning.
- Physical iPhone deployment still requires Apple developer provisioning and a registered device.
- Data analysis and data transformation commands are v1 array/file helpers, not a full DataFrame workspace.
- Plotting commands return chart-ready summaries. They do not render charts in the UI yet.
- iCloud sync, widgets, Shortcuts/App Intents, Mac Catalyst, full DataFrame workflows, and rendered charts are future work.

## Built-In Command Reference

The command reference below covers the 232 unique built-in command names currently registered by the app and groups them by the categories used in the UI. Angle-bracketed names indicate required parameters. `values...` means the command accepts a variable-length list. The Operations tab and Command Drawer remain the canonical in-app reference for the current build.

### Basic Arithmetic

| Command | What it does |
| --- | --- |
| `add <a> <b>` | Add two numbers. |
| `subtract <a> <b>` | Subtract `b` from `a`. |
| `multiply <a> <b>` | Multiply two numbers. |
| `divide <a> <b>` | Divide `a` by `b`. |
| `power <base> <exponent>` | Raise `base` to `exponent`. |
| `sqrt <x>` | Square root. |
| `factorial <n>` | Factorial of a non-negative integer. |
| `log <x> <base>` | Logarithm. Base defaults to 10 in command help. |
| `sin <x>` | Sine, radians. |
| `cos <x>` | Cosine, radians. |
| `tan <x>` | Tangent, radians. |
| `to_radians <degrees>` | Convert degrees to radians. |
| `to_degrees <radians>` | Convert radians to degrees. |
| `abs <x>` | Absolute value. |

### Trigonometry

| Command | What it does |
| --- | --- |
| `asin <x>` | Arcsine, returns radians. |
| `acos <x>` | Arccosine, returns radians. |
| `atan <x>` | Arctangent, returns radians. |
| `atan2 <y> <x>` | Two-argument arctangent. |
| `sinh <x>` | Hyperbolic sine. |
| `cosh <x>` | Hyperbolic cosine. |
| `tanh <x>` | Hyperbolic tangent. |
| `asinh <x>` | Inverse hyperbolic sine. |
| `acosh <x>` | Inverse hyperbolic cosine. |
| `atanh <x>` | Inverse hyperbolic tangent. |

### Advanced Math

| Command | What it does |
| --- | --- |
| `ceil <x>` | Round up to the nearest integer. |
| `floor <x>` | Round down to the nearest integer. |
| `round <x> <decimals>` | Round to a number of decimal places. |
| `trunc <x>` | Remove the decimal part. |
| `gcd <a> <b>` | Greatest common divisor. |
| `lcm <a> <b>` | Least common multiple. |
| `mod <a> <b>` | Remainder after division. |
| `exp <x>` | Calculate `e^x`. |

### Statistics

| Command | What it does |
| --- | --- |
| `mean <values...>` | Arithmetic mean. |
| `median <values...>` | Median. |
| `mode <values...>` | Most frequent value. |
| `geometric_mean <values...>` | Geometric mean. |
| `harmonic_mean <values...>` | Harmonic mean. |
| `variance <values...>` | Sample variance. |
| `pop_variance <values...>` | Population variance. |
| `std_dev <values...>` | Sample standard deviation. |
| `pop_std_dev <values...>` | Population standard deviation. |
| `range <values...>` | Maximum minus minimum. |
| `min <values...>` | Minimum value. |
| `max <values...>` | Maximum value. |
| `sum <values...>` | Sum of values. |
| `product <values...>` | Product of values. |
| `count <values...>` | Count of values. |

### Constants

| Command | What it does |
| --- | --- |
| `pi` | Return pi. |
| `e` | Return Euler's number. |
| `golden_ratio` | Return the golden ratio. |
| `speed_of_light` | Return speed of light in meters per second. |
| `planck` | Return Planck constant. |
| `avogadro` | Return Avogadro's number. |
| `boltzmann` | Return Boltzmann constant. |

### Unit Conversions

| Command | What it does |
| --- | --- |
| `celsius_to_fahrenheit <celsius>` | Celsius to Fahrenheit. |
| `fahrenheit_to_celsius <fahrenheit>` | Fahrenheit to Celsius. |
| `celsius_to_kelvin <celsius>` | Celsius to Kelvin. |
| `kelvin_to_celsius <kelvin>` | Kelvin to Celsius. |
| `miles_to_kilometers <miles>` | Miles to kilometers. |
| `kilometers_to_miles <kilometers>` | Kilometers to miles. |
| `feet_to_meters <feet>` | Feet to meters. |
| `meters_to_feet <meters>` | Meters to feet. |
| `inches_to_centimeters <inches>` | Inches to centimeters. |
| `centimeters_to_inches <centimeters>` | Centimeters to inches. |
| `pounds_to_kilograms <pounds>` | Pounds to kilograms. |
| `kilograms_to_pounds <kilograms>` | Kilograms to pounds. |
| `gallons_to_liters <gallons>` | Gallons to liters. |
| `liters_to_gallons <liters>` | Liters to gallons. |
| `mph_to_kph <mph>` | Miles per hour to kilometers per hour. |
| `kph_to_mph <kph>` | Kilometers per hour to miles per hour. |
| `hours_to_seconds <hours>` | Hours to seconds. |
| `minutes_to_seconds <minutes>` | Minutes to seconds. |
| `days_to_hours <days>` | Days to hours. |
| `weeks_to_days <weeks>` | Weeks to days. |
| `years_to_days <years>` | Years to days. |
| `seconds_to_milliseconds <seconds>` | Seconds to milliseconds. |
| `kb_to_bytes <kilobytes>` | Kilobytes to bytes. |
| `mb_to_bytes <megabytes>` | Megabytes to bytes. |
| `gb_to_bytes <gigabytes>` | Gigabytes to bytes. |
| `tb_to_bytes <terabytes>` | Terabytes to bytes. |
| `bytes_to_kb <bytes>` | Bytes to kilobytes. |
| `bytes_to_mb <bytes>` | Bytes to megabytes. |
| `bytes_to_gb <bytes>` | Bytes to gigabytes. |
| `bytes_to_tb <bytes>` | Bytes to terabytes. |
| `joules_to_calories <joules>` | Joules to calories. |
| `calories_to_joules <calories>` | Calories to joules. |
| `kwh_to_joules <kilowatt_hours>` | Kilowatt-hours to joules. |
| `joules_to_kwh <joules>` | Joules to kilowatt-hours. |
| `psi_to_pascal <psi>` | PSI to pascals. |
| `pascal_to_psi <pascal>` | Pascals to PSI. |
| `bar_to_pascal <bar>` | Bar to pascals. |
| `pascal_to_bar <pascal>` | Pascals to bar. |

### Geometry

| Command | What it does |
| --- | --- |
| `distance <x1> <y1> <x2> <y2>` | 2D distance between two points. |
| `distance3d <x1> <y1> <z1> <x2> <y2> <z2>` | 3D distance between two points. |
| `area_circle <radius>` | Area of a circle. |
| `circumference <radius>` | Circumference of a circle. |
| `area_triangle <base> <height>` | Triangle area from base and height. |
| `area_triangle_heron <a> <b> <c>` | Triangle area using Heron's formula. |
| `pythagorean <a> <b>` | Hypotenuse from two sides. |
| `pythagorean_side <hypotenuse> <side>` | Missing side from hypotenuse and one side. |
| `area_rectangle <length> <width>` | Rectangle area. |
| `perimeter_rectangle <length> <width>` | Rectangle perimeter. |
| `area_square <side>` | Square area. |
| `volume_sphere <radius>` | Sphere volume. |
| `surface_area_sphere <radius>` | Sphere surface area. |
| `volume_cylinder <radius> <height>` | Cylinder volume. |
| `area_regular_polygon <sides> <side_length>` | Area of a regular polygon. |

### Combinatorics

| Command | What it does |
| --- | --- |
| `combinations <n> <r>` | Number of combinations, n choose r. |
| `permutations <n> <r>` | Number of permutations, n permute r. |
| `fibonacci <n>` | Nth Fibonacci number. |
| `is_even <n>` | Check if even. |
| `is_odd <n>` | Check if odd. |
| `is_perfect_square <n>` | Check if a perfect square. |
| `digit_sum <n>` | Sum of digits. |
| `reverse_number <n>` | Reverse digits. |

### Number Theory

| Command | What it does |
| --- | --- |
| `next_prime <n>` | Next prime after `n`. |
| `prime_count <n>` | Count primes up to `n`. |
| `euler_phi <n>` | Euler's totient function. |
| `divisors <n>` | All divisors of `n`. |
| `perfect_number <n>` | Check if `n` is a perfect number. |
| `catalan <n>` | Nth Catalan number. |
| `bell_number <n>` | Nth Bell number. |
| `stirling <n> <k>` | Stirling number of the second kind. |
| `partition <n>` | Number of partitions of `n`. |
| `mobius <n>` | Mobius function. |
| `totient <n>` | Alias for Euler's totient. |
| `is_prime <n>` | Check primality. |
| `prime_factors <n>` | Prime factors of a number. |

### Complex Numbers

| Command | What it does |
| --- | --- |
| `cadd <real1> <imag1> <real2> <imag2>` | Add complex numbers. |
| `csub <real1> <imag1> <real2> <imag2>` | Subtract complex numbers. |
| `cmul <real1> <imag1> <real2> <imag2>` | Multiply complex numbers. |
| `cdiv <real1> <imag1> <real2> <imag2>` | Divide complex numbers. |
| `magnitude <real> <imag>` | Magnitude of a complex number. |
| `phase <real> <imag>` | Phase in radians. |
| `conjugate <real> <imag>` | Complex conjugate. |
| `polar <magnitude> <phase>` | Convert polar to rectangular form. |
| `rectangular <real> <imag>` | Convert rectangular coordinates to `[magnitude, phase]`. |
| `csqrt <real> <imag>` | Complex square root. |
| `cexp <real> <imag>` | Complex exponential. |
| `clog <real> <imag>` | Natural log of a complex number. |
| `csin <real> <imag>` | Sine of a complex number. |
| `ccos <real> <imag>` | Cosine of a complex number. |
| `ctan <real> <imag>` | Tangent of a complex number. |
| `cpower <real1> <imag1> <real2> <imag2>` | Raise one complex number to another complex power. |
| `cis <theta>` | `cos(theta) + i*sin(theta)`. |
| `real_part <real> <imag>` | Real component. |
| `imag_part <real> <imag>` | Imaginary component. |

### Variables

| Command | What it does |
| --- | --- |
| `set <name> <value>` | Set a variable. Also accepts expression values, such as `set x 7 + 9`. |
| `persist <name>` | Mark a variable persistent. |
| `get <name>` | Get a variable value. |
| `vars` | List variables. |
| `unset <name>` | Delete one variable. |
| `clear_vars` | Clear all variables. |

### Control Flow

| Command | What it does |
| --- | --- |
| `eq <a> <b>` | Check equality. |
| `neq <a> <b>` | Check inequality. |
| `gt <a> <b>` | Greater than. |
| `gte <a> <b>` | Greater than or equal. |
| `lt <a> <b>` | Less than. |
| `lte <a> <b>` | Less than or equal. |
| `and <a> <b>` | Logical AND. |
| `or <a> <b>` | Logical OR. |
| `not <value>` | Logical NOT. |
| `if <condition> <then_value> <else_value>` | Conditional value selection. |
| `is_number <value>` | Check whether a value is numeric. |
| `is_string <value>` | Check whether a value is a string. |
| `is_bool <value>` | Check whether a value is boolean. |

### User Functions

| Command | What it does |
| --- | --- |
| `def <name> <parameters...> <body>` | Define a user function. |
| `funcs` | List user-defined functions. |
| `undef <name>` | Delete a user-defined function. |

### Scripts

| Command | What it does |
| --- | --- |
| `run <filepath>` | Run a `.mathcli` script file. |
| `eval <expression>` | Evaluate an expression string. |

### Export/Integration

| Command | What it does |
| --- | --- |
| `export_session <filepath> <format>` | Export session data. |
| `import_session <filepath> <merge>` | Import session data. |
| `export_vars <filepath>` | Export variables as JSON. |
| `import_vars <filepath>` | Import variables from JSON. |
| `export_funcs <filepath>` | Export user functions as JSON. |
| `import_funcs <filepath>` | Import user functions from JSON. |

### Matrix Operations

| Command | What it does |
| --- | --- |
| `det <matrix>` | Matrix determinant. |
| `transpose <matrix>` | Matrix transpose. |
| `eigenvalues <matrix>` | Real eigenvalues. |
| `eigenvectors <matrix>` | Eigenvectors. |
| `trace <matrix>` | Sum of diagonal values. |
| `rank <matrix>` | Matrix rank. |
| `inverse <matrix>` | Matrix inverse. |
| `matrix_multiply <matrix1> <matrix2>` | Matrix multiplication. |
| `identity <n>` | Identity matrix. |
| `zeros <rows> <cols>` | Matrix of zeros. |
| `ones <rows> <cols>` | Matrix of ones. |
| `diagonal <values...>` | Diagonal matrix from values. |

Matrix arguments are represented in the command engine as matrix values. The current UI is best suited to generated matrices such as `identity`, `zeros`, `ones`, and `diagonal`, plus matrix values produced by previous commands.

### Calculus

| Command | What it does |
| --- | --- |
| `derivative <coefficient> <exponent> <x>` | Derivative of `a*x^n` at `x`. |
| `derivative2 <coefficient> <exponent> <x>` | Second derivative of `a*x^n` at `x`. |
| `partial <expr> <var>` | V1 polynomial-form partial derivative helper. |
| `gradient <values...>` | Numerical gradient of an array. |
| `divergence <x_values> <y_values>` | Divergence from two equal-length arrays. |
| `laplacian <values...>` | Second derivative approximation over values. |
| `integrate <coefficient> <exponent> <a> <b>` | Definite integral of `a*x^n` from `a` to `b`. |
| `integrate_symbolic <coefficient> <exponent>` | Symbolic integral of `a*x^n`. |
| `limit <coefficient> <exponent> <point>` | Limit of `a*x^n` as `x` approaches a point. |
| `taylor <function> <center> <terms>` | Taylor approximation for supported functions such as `exp`, `sin`, and `cos`. |
| `series <start> <end> <step>` | Arithmetic series. |
| `solve_ode <slope> <y0> <x0> <x_end> <steps>` | Euler-method ODE helper for `dy/dx = slope`. |

### Data Analysis

| Command | What it does |
| --- | --- |
| `load_data <filepath>` | Inspect a CSV file and report row/column counts. |
| `describe_data <values...>` | Statistical summary of values. |
| `correlation_matrix <array1> <array2>` | Correlation between two arrays. |
| `groupby <values...> <groups...>` | V1 grouped-summary helper. |
| `detect_outliers <values...>` | IQR-based outlier detection. |
| `missing_values <values...>` | Count missing/zero values. |
| `pivot_table <values...>` | V1 pivot-style total summary. |
| `rolling_mean <window_size> <values...>` | Rolling mean. |
| `time_series_analysis <values...>` | Trend summary for values. |
| `data_info <values...>` | Data information summary. |
| `save_data <filepath> <values...>` | Save values to CSV. |
| `unique_values <values...>` | Unique values. |

### Data Transformation

| Command | What it does |
| --- | --- |
| `filter_data <threshold> <values...>` | Keep values greater than a threshold. |
| `normalize_data <values...>` | Normalize values to `[0, 1]`; constant arrays return `0.5` values. |
| `sort_data <ascending> <values...>` | Sort values. |
| `aggregate_data <function> <values...>` | Aggregate with `sum`, `mean`, `max`, or `min`. |
| `fill_nulls <fill_value> <values...>` | Replace zero values with a fill value. |
| `drop_nulls <values...>` | Remove zero values. |
| `merge_data <array1...> <array2...>` | Merge values. |
| `sample_data <n> <values...>` | Random sample of `n` values. |
| `add_column <value> <values...>` | Add a constant to each value. |
| `drop_column <index> <values...>` | Drop the value at an index. |
| `rename_column <old_name> <new_name>` | Return a V1 rename mapping. |

### Plotting

| Command | What it does |
| --- | --- |
| `plot_hist <bins> <values...>` | Prepare histogram data. |
| `plot_box <values...>` | Prepare box plot data. |
| `plot_scatter <x_values> <y_values>` | Prepare scatter plot data. |
| `plot_heatmap <matrix>` | Prepare heatmap data from a matrix. |
| `plot <values...>` | Generic plot summary. |
| `plot_line <values...>` | Prepare line plot data. |
| `plot_bar <values...>` | Prepare bar chart data. |
| `plot_data <data_source> <x_column> <y_column>` | Plot data from a named source/columns. |

Plotting commands return deterministic summaries or chart-ready data. They do not render Swift Charts views yet.
