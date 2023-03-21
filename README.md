# vete

Ruby CLI to spawn processes to get work done

The phrase "¡véte!" in Spanish means, basically, "Get out!". This tool helps to clear out work in a hurry, using a simple approach of spawning a set number of concurrent processes to handle each job. Jobs are defined as files in a directory, so there is no need for a database or any other complexity.

### Example

Running the `test/example.rb` script with 10 workers:

![Example](https://raw.githubusercontent.com/shreeve/vete/main/test/vete.gif)
