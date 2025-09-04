# print - Universal Output Function

## Usage
print [OPTIONS] [TEXT]...

## Description
Unified Output Function for formatted Console Output with Colors, Positioning, and special Formatting Options.

## Options

### Colors
- NC - No Color (reset)
- RD - Red
- GN - Green  
- YE - Yellow
- BU - Blue
- CY - Cyan
- WH - White
- MG - Magenta

### Positioning
- -l POS - Left align at position
- -r POS - Right align at position

### Line Control
- --cr [N] - Print N newlines (default: 1)
- --no-nl, -n - Suppress automatic newline

### Special Operations
- --success MESSAGE - Print success message with green checkmark
- --error MESSAGE - Print error message with red X
- --warning MESSAGE - Print warning message with yellow warning sign
- --info MESSAGE - Print info message with blue info icon
- --header TITLE - Print formatted header with borders
- --line [CHAR] - Print horizontal line (default: #)

### Help
- --help, -h - Show this help message

## Examples

```bash
# Simple text output
print "Hello World"

# Colored text
print GN "Success!" 

# Positioned text
print -l 4 "Name:" -l 20 "John Doe"

# Special messages
print --success "Operation completed"
print --error "Failed to connect"

# Multiple lines
print "Line 1" --cr 2 "Line 2"

# Without newline
print -n "Loading..."