package com.valkyrie.launcher;

import javafx.application.Application;

public final class LauncherMain {
    private LauncherMain() {}

    public static void main(String[] args) {
        // Ошибка до появления окна иначе исчезает: у собранного jpackage-лаунчера
        // нет консоли, а javafx.application.Application.launch глотает исключение
        // из start(). Пользователь получает «ничего не запускается» без единого
        // слова о причине, поэтому ловим и логируем, и показываем.
        Thread.setDefaultUncaughtExceptionHandler((thread, error) ->
            LauncherFailure.report("Поток " + thread.getName() + " завершился с ошибкой", error));
        try {
            Application.launch(ValkyrieLauncherApp.class, args);
        } catch (Throwable error) {
            LauncherFailure.report("Не удалось инициализировать JavaFX", error);
            System.exit(1);
        }
    }
}
