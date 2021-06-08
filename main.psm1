<# if you think i know how this works, you're insane #>

class Attribute{
    [string]$Key
    [string]$Value #cast to string for the moment. can recast later as needed.
    
    [int]StringLength()
    {
        return ($this.key.length + $this.value.length + 3)
    }
}

class Element {
    [String]$Type
    [System.Collections.ArrayList]$Attributes = @()
    [System.Collections.ArrayList]$Children = @()
    [Bool]$opener
    [Bool]$closer
    [Bool]$selfContained
    [Int]$length
    #[String]$content //won't work. needs location and data

    init ($t,$i) {
        if($t[$i] -eq "<")
        {
            $init = $i
            $i++

            if($t[$i] -eq '/')
            {
                $this.closer = $true
                $i++
            }
            else
            {
                $this.closer = $false
            }

            $this.type = (Get-Type -text $t -index $i)
            $i+=$this.type.length

            while($t[$i] -match '[\s]')
            {
                $i++
                $attribute = (Get-Attribute -text $t -index $i)
                $i+=$attribute.StringLength()
                #Write-Host ($attribute.Key+" = "+$attribute.Value)
                $this.Attributes.Add($attribute)
            }

            if(($t[$i] -eq '/') -and ($t[$i+1] -eq '>'))
            {
                $this.selfContained = $true
                $i++
            }
            elseif($t[$i] -eq '>')
            {
                $this.selfContained = $false

                if(!$this.closer)
                {
                    $this.opener = $true
                }
                else
                {
                    $this.opener = $false
                }
            }
            else
            {
                Write-Error "Expected /> or >"
            }

            $this.length = $i - $init
        }
        else
        {
            Write-Error "Expected <"
        }
    }

    [String]print () {
        $attrs = ""

        foreach($attr in $this.Attributes)
        {
            $attrs+=$attr.Key+"="+$attr.Value+" "
        }

        $details = $this.Type + " " + $attrs

        return $details
    }
}

function Get-Type {
    param (
        $text,
        $index
    )

    $type = ""

    while($text[$index] -match '[A-Za-z]')
    {
        $type+=$text[$index]
        $index++
    }
    
    return $type
}

function Get-Attribute {
    param (
        $text,
        $index
    )

    $key = ""

    if($text[$index] -match '[A-Za-z]')
    {
        while($text[$index] -match '[A-Za-z]')
        {
            $key+=$text[$index]
            $index++
        }
    }
    else
    {
        Write-Error "Expected attribute key"
    }

    if($text[$index] -eq "=")
    {
        $index++
        if($text[$index] -match '[`"'']')
        {
            $quote = $text[$index] #set quote to equal the type of quote used
            $index++
            $value = ""
            while($text[$index] -ne $quote)
            {
                $value+=$text[$index]
                $index++
            }
        }
        else
        {
            Write-Error "Missing opening quotes"
        }
    }
    else
    {
        Write-Error "Missing '='"
    }

    [Attribute]$output = [Attribute]::New()
    $output.Key = $key
    $output.Value = $value

    return [Attribute]$output
}

function New-PsXml {
    param (
        [String]$Path
    )

    $file = "$PSScriptRoot\example.xml"

    $t = Get-Content $Path -Raw #text
    $i = 0 #index

    [System.Collections.ArrayList]$parentStack = @()
    $root = [Element]::new()
    $root.Type = "root"
    $root.selfContained = $true

    $parentStack.Add($root) | Out-Null

    while($i -lt $t.Length)
    {
        #regular elements
        if($t[$i] -eq "<")
        {
            #string break
            $contentCheck = $false

            $element = [Element]::new()
            $element.init($t,$i)
            $i+=$element.length+1

            if($element.selfContained -or $element.opener)
            {
                ([Element]($parentStack[-1])).Children.Add($element) | Out-Null
            }

            if($element.opener)
            {
                $parentStack.Add($element) | Out-Null
            }
            elseif($element.closer)
            {
                $parentStack.Remove(-1) | Out-Null
            }
        }

        #text/content stuff
        elseif($t[$i] -match '[\w\s]')
        {
            [Element]$element = [Element]::new()
            $element.Type = "content"

            [Attribute]$attr = [Attribute]::new()
            $attr.Key = "text"

            $string = ""
            while($t[$i] -match '[\w\s]')
            {
                $string+=$t[$i]
                $i++
            }

            $attr.Value = $string.Replace("`t","").Replace("  "," ").Replace("`n","").Replace("`r","")
            $element.Attributes.Add([Attribute]$attr)

            if($string -match '[\S]')
            {
                ([Element]($parentStack[-1])).Children.Add($element) | Out-Null
            }
            else
            {
                #do nothing, don't add it to the thing.
            }
        }

        else
        {
            Write-Error "Expected element or content. Bad formatting or empty doc."
        }
    }

    Write-Output ([Element]$root)
}

function Get-Children {
    param (
        $Element, #can't set this to element type or it breaks for some reason
        [Bool]$Recursive
    )

    foreach($child in $element.Children)
    {
        $child.print()
        if($Recursive)
        {
            Get-Children $child -recursive $true
        }
    }
}
