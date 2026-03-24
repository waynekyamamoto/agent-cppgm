#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <signal.h>
#include <string.h>
#include <stdlib.h>

extern "C" int __real_main(int argc, char** argv);

int run_test_with_timeout(int argc, char** argv, const std::string& stdin_file, const std::string& stdout_file, const std::string& stderr_file) {
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        return EXIT_FAILURE;
    }
    
    if (pid == 0) {
        if (stdin_file != "-" && !stdin_file.empty()) {
            freopen(stdin_file.c_str(), "r", stdin);
        }
        if (stdout_file != "-" && !stdout_file.empty()) {
            freopen(stdout_file.c_str(), "w", stdout);
        }
        if (stderr_file != "-" && !stderr_file.empty()) {
            if (stderr_file == stdout_file) {
                dup2(fileno(stdout), fileno(stderr));
            } else {
                freopen(stderr_file.c_str(), "w", stderr);
            }
        }
        exit(__real_main(argc, argv));
    }
    
    int status;
    int timeout_ms = 10000;
    while (timeout_ms > 0) {
        pid_t res = waitpid(pid, &status, WNOHANG);
        if (res == pid) {
            if (WIFEXITED(status)) {
                return WEXITSTATUS(status);
            } else if (WIFSIGNALED(status)) {
                return 128 + WTERMSIG(status);
            }
            return EXIT_FAILURE;
        } else if (res < 0) {
            return EXIT_FAILURE;
        }
        usleep(10000);
        timeout_ms -= 10;
    }
    
    kill(pid, SIGKILL);
    waitpid(pid, &status, 0);
    return 124; // standard timeout exit code
}

extern "C" int __wrap_main(int argc, char** argv) {
    if (argc >= 3 && std::string(argv[1]) == "--batch-file") {
        std::ifstream batch(argv[2]);
        if (!batch.is_open()) {
            std::cerr << "Failed to open batch file " << argv[2] << std::endl;
            return EXIT_FAILURE;
        }
        
        std::string line;
        while (std::getline(batch, line)) {
            if (line.empty() || line[0] == '#') continue;
            
            std::istringstream iss(line);
            std::string exit_status_file, exit_status_format, stdout_file, stderr_file, stdin_file;
            if (!(iss >> exit_status_file >> exit_status_format >> stdout_file >> stderr_file >> stdin_file)) {
                continue;
            }
            
            std::vector<std::string> args;
            std::string arg;
            while (iss >> arg) {
                args.push_back(arg);
            }
            
            std::vector<char*> c_args;
            for (auto& a : args) {
                c_args.push_back(const_cast<char*>(a.c_str()));
            }
            c_args.push_back(nullptr);
            
            int ret = run_test_with_timeout(c_args.size() - 1, c_args.data(), stdin_file, stdout_file, stderr_file);
            
            if (exit_status_file != "-") {
                std::ofstream out(exit_status_file);
                if (exit_status_format == "num") {
                    out << ret << "\n";
                } else {
                    if (ret == 0) out << "EXIT_SUCCESS\n";
                    else if (ret == 124) out << "EXIT_TIMEOUT\n";
                    else if (ret > 128) out << "EXIT_CRASH\n";
                    else out << "EXIT_FAILURE\n";
                }
            }
        }
        return EXIT_SUCCESS;
    }
    
    return run_test_with_timeout(argc, argv, "-", "-", "-");
}
