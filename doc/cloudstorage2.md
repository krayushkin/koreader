# Tecnical requerments for cloudstorage2 (CS)

Methods that providers need to implement:

## configFilelds - table with description of dialog fields (optional)

Array of tables

```
{
    {
        field_name = String (required),
        optional = (true | false) (optional, default = false),
        type = ("string" | "bool" | "number") (optional, default = "string"),
        help = String (optional, default = ""),
    },
}
```

Example:

```
configFields = {
    {
        field_name = "Name",
        optional = false,
        type = "string",
        help = "Any, just for entry name",
    },
    {
        field_name = "Token",
        optional = false,
        type = "string",
        help = "from BotFather",
    },
}
```

## config(data) - function used for first configuration and provider initialization

## info()

## list()

## download()

## sync()

# Configuration workflow:

CS ask provider what fields must be presented in configuration.

CS show menu to user with that fields and return to provider.

If current provider was already configured then CS not show form to user,
load config from persistent storage and then return configuration data to provider.

Provider verify configuration data. If verification is ok then provider return ok status
with same configuration object. Else it return error status with error message.

If provider verification returned ok, then CS saves data to persistent storage and close form.
Else it display error message and configuration continue.



