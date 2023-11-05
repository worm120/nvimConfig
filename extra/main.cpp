#include <iostream>
//#include <windows.h>
#include <chrono>
#include <functional>
#include <thread>
#include "kaguya/kaguya.hpp"

static std::vector<std::thread> tPool;
static bool isRunning = true;
static kaguya::State state;

class ABC
{
public:
	ABC() :v_(0) {
		printf("ABC constructed\n");
	}
	ABC(int value) :v_(value) {}
	~ABC() {
		printf("ABC destructed\n");
	}
	int value()const { return v_; }
	void setValue(int v) { v_ = v; }
	void overload1() { std::cout << "call overload1" << std::endl; }
	void overload2(int) { std::cout << "call overload2" << std::endl; }
	void takesLongTime() {
		//Sleep(3000);
		printf("takesLongTime called\n");
		std::this_thread::sleep_for(std::chrono::milliseconds(3000));
		printf("takesLongTime execute finished\n");
	}

	void takesLongTime2() {
		//Sleep(3000);
		printf("takesLongTime2 called\n");
		std::this_thread::sleep_for(std::chrono::milliseconds(6000));
		printf("takesLongTime2 execute finished\n");
	}
private:
	int v_;
};

void submitToOtherThread(kaguya::LuaFunction fun) {
	//fun();
	auto sharedFun = std::make_shared<kaguya::LuaFunction>(fun);
	tPool.push_back(std::thread([sharedFun]() {
		(*sharedFun)();
		//fun();
		printf(" thread finished\n");
	}));
}

void eventLoop() {
	while (isRunning) {
		printf("event loop\n");
		state["eventFun"]();
		std::this_thread::sleep_for(std::chrono::milliseconds(1000));
	}
}

int setTimeout(uint64_t timeoutMs, kaguya::LuaFunction fun) {
	return -1;
}

int setTimeInterval(uint64_t timeoutMs, kaguya::LuaFunction fun) {

	return -1;
}

void stopTimer(int timerId) {

}

int main(int argc, char** argv) {
	//kaguya::LuaRef a = state["a"];

	state["ABC"].setClass(kaguya::UserdataMetatable<ABC>()
		.setConstructors<ABC(), ABC(int)>()
		.addFunction("get_value", &ABC::value)
		.addFunction("set_value", &ABC::setValue)
		.addFunction("takesLongTime", &ABC::takesLongTime)
		.addFunction("takesLongTime2", &ABC::takesLongTime2)
		.addOverloadedFunctions("overload", &ABC::overload1, &ABC::overload2)
		.addStaticFunction("nonmemberfun", [](ABC* self, int) {return 1; })//c++11 lambda function
	);
	state["submitToOtherThread"] = submitToOtherThread;
	state["eventLoop"] = eventLoop;
	state["setTimeout"] = setTimeout;
	state["setTimeInterval"] = setTimeInterval;
	state["stopTimer"] = stopTimer;
	state.dofile("C:\\code\\lua_test\\lua_test\\test.lua");
	printf("a=%d\n", state["a"].get<int>());
	for (auto& t : tPool) {
		t.join();
	}
	return 0;
}