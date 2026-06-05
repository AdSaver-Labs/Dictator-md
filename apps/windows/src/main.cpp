#include "App.h"

#include <windows.h>

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int showCommand) {
    App app;
    return app.run(instance, showCommand);
}
