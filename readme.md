# Mock-Json

Creates mock data in json format with a custom template determining the contents of the generated data.

## Usage
```
  perl mock-json.pl --template="template.json" --out="mock.json" --amount=20
```

## Flags
    --help, -h, /h, /help
        Display this help text.
    --template=<filename>
        Template file to determine what to output.
        Format of the template is shown in the file example-template.json.
    --amount
        Amount of objects to generate.
    --out=<filename>
        File to write into, if not provided, prints to stdout.
    --pretty
        Pretty prints the outputted json.
    --overwrite
        Overwrites the output file if it exists.

## Template
``` json
{
    "id": {                     # Name of the generated field
        "type": "integer",      # Type: integer, decimal, text
        "method": "increment",  # Increment or random
        "start": 1,             # Starting value for increment
        "increment": 1          # Amount to increment each time
    },

    "someNumber": {
        "type": "integer",
        "method": "random",    
        "start": 1,             # Minimum value for random number generation
        "end": 1000             # Maximum value for random number generation
    },

    "someValue": {
        "type": "decimal",
        "method": "random",
        "start": 250.0,
        "end": 750.0,
        "precision": 1          # How many decimals to use.
    },
    
    "firstname": {
        "type": "text",
        "method": "random",
        "file": "firstnames",   # Filename of source lines of data.
        "repeat": 2,            # How many lines to grab from source data.
        "separator": " "        # Text to insert between data if repeating.
    },
    
    "lastname": {
        "type": "text",
        "method": "random",
        "file": "lastnames"
    },

    "description": {
        "type": "text",
        "method": "random",
        "file": "loremipsum",  
        "repeat": 3,        
        "separator": "&#010;"
    }
}
```
