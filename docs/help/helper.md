# Print Function Help

## Usage
`print [OPTION] [MESSAGE]`

## Description
Unified print function for formatted console output with colors, positioning and alignment support.

## Options

### Output Types
- `--success MESSAGE` - Print success message with green color and ✓ symbol
- `--error MESSAGE` - Print error message with red color and ✗ symbol  
- `--warning MESSAGE` - Print warning message with yellow color and ⚠ symbol
- `--info MESSAGE` - Print info message with cyan color and ℹ symbol
- `--header TITLE` - Print formatted header with title

### Formatting
- `--line [CHAR]` - Print horizontal line with specified character (default: #)
- `--pos COLUMN` - Set column position for output
- `--left, -l` - Left align text (default)
- `--right, -r` - Right align text
- `--cr [N]` - Print N newlines (default: 1)

### Help
- `--help, -h` - Show this help message

## Examples
```bash
print --success "Operation completed"
print --error "File not found" 
print --pos 20 "Indented text"
print --right "Right aligned"
print --cr 2