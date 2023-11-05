a = 1
b = 2
abc = ABC.new()
local co = nil

local function foo()
    print("foo start")
    local finished = false
    submitToOtherThread(
        function ()
            print("submit")
            abc:takesLongTime()
            finished = true
        end
    )
    while not finished do
        print("yield foo 1")
        coroutine.yield()
    end
    finished = false
    submitToOtherThread(
        function ()
            print("submit2")
            abc:takesLongTime2()
            finished = true
        end
    )
    while not finished do
        print("yield foo 2")
        coroutine.yield()
    end
end

function eventFun()
    if co == nil then
        co = coroutine.create(foo)
    else
        if coroutine.status(co) ~= "dead" then
            coroutine.resume(co)
        else
            print("coroutine finished")
        end
    end

end

-- abc = nil

eventLoop()
