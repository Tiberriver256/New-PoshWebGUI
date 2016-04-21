# Create HttpListener Object
$SimpleServer = New-Object Net.HttpListener

# Tell the HttpListener what port to listen on
#    As long as we use localhost we don't need admin rights. To listen on externally accessible IP addresses we will need admin rights
$SimpleServer.Prefixes.Add("http://localhost:8000/")

# Start up the server
$SimpleServer.Start()

# Tell the server to wait for a request to come in on that port.
$Context = $SimpleServer.GetContext()

#Once a request has been captured the details of the request and the template for the response are created in our $context variable
Write-Verbose "Context has been captured"

# $Context.Request contains details about the request
# $Context.Response is basically a template of what can be sent back to the browser
# $Context.User contains information about the user who sent the request. This is useful in situations where authentication is necessary


# Sometimes the browser will request the favicon.ico which we don't care about. We just drop that request and go to the next one.
do
{

    $Context.Response.Close()
    $Context = $SimpleServer.GetContext()

}while($Context.Request.Url.LocalPath -eq "/favicon.ico")


# Handling different URLs

# We do a simple if statement to determine what response we want to send based on the url requested.
if($Context.Request.Url.LocalPath -eq "/processList")
{

    #We get a list of processes, choose the properties we want, convert it to HTML, convert the array created by the convertto-HTML cmdlet to a string and we have a result ready
    $result = Get-Process | select name,cpu | ConvertTo-Html | Out-String

}
else 
{

    $result = "<html><body>Hello World!</body></html>"

}







# In order to send it to the browser we need to convert it from ASCII encoded text into bytes.
$buffer = [System.Text.Encoding]::ASCII.GetBytes($result)

# We need to let the browser know how many bytes we are going to be sending
$context.Response.ContentLength64 = $buffer.Length

# We send the response back to the browser
$context.Response.OutputStream.Write($buffer, 0, $buffer.Length)

# We close the response to let the browser know we are done sending the response
$Context.Response.Close()

# We stop our server
$SimpleServer.Stop()