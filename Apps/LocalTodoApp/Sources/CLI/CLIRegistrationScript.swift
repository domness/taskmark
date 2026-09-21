import Foundation

/// All interpolated paths are shell-quoted, then the complete command is AppleScript-quoted.
enum CLIRegistrationScript {
    static func command(enabled: Bool, source: URL, destination: URL) -> String {
        let preamble = """
        set -eu
        source=\(shellQuote(source.path))
        destination=\(shellQuote(destination.path))
        if [ -L "$destination" ]; then
            target=$(/usr/bin/readlink "$destination")
            case "$target" in
                "$source"|*/Taskmark.app/Contents/Helpers/taskmark) ;;
                *)
                    /bin/echo 'Another command uses /usr/local/bin/taskmark. Move it before trying again.' >&2
                    exit 1 ;;
            esac
        elif [ -e "$destination" ]; then
            /bin/echo 'A file already exists at /usr/local/bin/taskmark. Move it before trying again.' >&2
            exit 1
        fi
        """
        if !enabled {
            return preamble + "\nif [ -L \"$destination\" ]; then /bin/rm \"$destination\"; fi"
        }
        return preamble + "\n" + """
        if [ ! -x "$source" ]; then
            /bin/echo 'The bundled taskmark command is missing. Reinstall Taskmark.' >&2
            exit 1
        fi
        directory=\(shellQuote(destination.deletingLastPathComponent().path))
        /bin/mkdir -p "$directory"
        if [ -L "$destination" ]; then
            temporary=$(/usr/bin/mktemp -d "$directory/.taskmark-registration.XXXXXX")
            trap '/bin/rm -f "$temporary/taskmark"; /bin/rmdir "$temporary"' EXIT
            /bin/ln -s "$source" "$temporary/taskmark"
            /bin/mv -fh "$temporary/taskmark" "$destination"
        else
            /bin/ln -s "$source" "$destination"
        fi
        """
    }

    static func authorizationScript(command: String) -> String {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(escaped)\" with administrator privileges"
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
