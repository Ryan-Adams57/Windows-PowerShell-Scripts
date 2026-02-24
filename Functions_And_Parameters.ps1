# Simple reusable function
function Foo {
    Write-Host "Hello from Foo"
}
Foo

# Function with parameter
function FooParam ($Bar) {
    Write-Host "Parameter passed: $Bar"
}
FooParam -Bar "TestValue"
