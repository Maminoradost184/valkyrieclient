package com.valkyrie.launcher;

import java.awt.GraphicsEnvironment;
import java.awt.Toolkit;
import java.awt.datatransfer.StringSelection;

/**
 * Аварийный выход для ошибок, из-за которых окно лаунчера не появилось.
 *
 * <p>Установленный лаунчер запускается как GUI-приложение без консоли, и
 * {@code stderr} у него некуда деваться: исключение, брошенное до
 * {@code stage.show()}, уходит в никуда. Пользователь видит только «ничего не
 * произошло» и не может отличить сломанный JavaFX от сломанной распаковки или
 * от старого конфига. Для машины, до которой нет физического доступа, это
 * неразличимые случаи.
 *
 * <p>Здесь ошибка попадает в журнал и в диалог с готовым текстом, который
 * сразу кладётся в буфер обмена, чтобы его можно было отправить в поддержку
 * без фотографии экрана.
 */
final class LauncherFailure {
    private static boolean reported;

    private LauncherFailure() {}

    static synchronized void report(String context, Throwable error) {
        if (reported) return;
        reported = true;
        LauncherLog.error(context, error);
        String report = describe(context, error);
        if (GraphicsEnvironment.isHeadless()) return;
        copyToClipboard(report);
        javax.swing.JOptionPane.showMessageDialog(null, report,
            "Valkyrie Launcher — не удалось запуститься", javax.swing.JOptionPane.ERROR_MESSAGE);
    }

    private static String describe(String context, Throwable error) {
        return new StringBuilder()
            .append("Valkyrie Launcher ").append(LauncherVersion.VALUE).append(" не удалось запустить.")
            .append(System.lineSeparator()).append(System.lineSeparator())
            .append(context).append(System.lineSeparator())
            .append(error).append(System.lineSeparator()).append(System.lineSeparator())
            .append("Подробности в журнале:").append(System.lineSeparator())
            .append(LauncherLog.path()).append(System.lineSeparator()).append(System.lineSeparator())
            .append("Текст ошибки скопирован в буфер обмена.")
            .toString();
    }

    private static void copyToClipboard(String text) {
        try {
            Toolkit.getDefaultToolkit().getSystemClipboard().setContents(new StringSelection(text), null);
        } catch (RuntimeException ignored) {
        }
    }
}
