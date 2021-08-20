using Test
using Alert

# without a backend, `alert` should error
if get(ENV,"CI",false)
    @test_throws ErrorException alert()
else
    @test alert() !== nothing
end