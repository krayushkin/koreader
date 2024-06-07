# Tecnical requerments for cloudstorage2 (CS)

Methods that providers need to implement:

## configForm - table with description of configuration form (optional)

configForm data object description:

```
registerProvider("telegram", { 
    supportMultipleSelect = (true | false) (optional, default = false),
    configForm = {
        title = String (required),
        info = String (required),
        fields = {
            {
                field_name = String (required),
                optional = (true | false) (optional, default = false),
                type = ("string" | "bool" | "number") (optional, default = "string"),
                desc = String (optional, default = ""),
            },
            ...
        }
    }
})
```

Example:

```
configForm = {
    title = _("Telegram bot configuration"),
    info = _([[Some long description how to properly configure provider]]),
    fields = {
        {
            field_name = _("Name"),
            optional = false,
            type = "string",
            desc = _("Any, just for entry name"),
        },
        {
            field_name = _("Token"),
            optional = false,
            type = "string",
            desc = _("from BotFather"),
        },
    }
}
```

## config(data) - function used for first configuration and provider initialization

## info()

## list()

`list(url) -> listItem` return list of remote (or maybe localy) objects that current provider provide.

Input arguments:

`url` - current url that user want to see. Sequence table with string values that
represent hierarchy tree. For example: `{"home", "user", "books"}`. `{}` is root derectory.

Output structure:

```
listItems = {
    {
        -- displayed name
        name = String (requred), 
        
        -- hint for CS
        type = ("file" | "folder" | "other") (requred), 
        
        -- small text displayed on right of item 
        mandatory = (String | nil) (optional, defalut = nil),
       
        -- regular or dimmed text
        dim = (true | false) (optional, default = false),         

        -- user may click on item
        clickable = (true | false) (optional, default = true),         
     
        -- item displayed bold text
        bold = (true | false) (optional, default = false),        
        
        -- any data, you may use it for any metadata, file_id for example
        data = AnyType (optional, default = nil),
    },
    ...

}
```

## download(listItems)


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



