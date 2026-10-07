# Contributing to Hadoop + Hive + PySpark Lab Setup

Thank you for helping make this Big Data lab setup easier and more reliable for students worldwide!

---

## 🎯 How You Can Contribute

1. **Bug Reports**:
   - Found a dist-upgrade issue, package incompatibility, or JVM warning? Open an [Issue](https://github.com/adhimiw/hadoop-hive-pyspark-lab/issues).
   - Please include your OS (`cat /etc/os-release`), Java version (`java -version`), and the relevant lines from `logs/`.

2. **OS & Architecture Support**:
   - We currently support Ubuntu, Debian, CentOS, RHEL, and Fedora.
   - Tested on Arch Linux, openSUSE, or ARM64 / Apple Silicon (UTM / Parallels)? Contributions and verified installation steps are welcome!

3. **Lab Curriculum & Exercises**:
   - Add new exercises, Spark DataFrame transformations, MLlib notebooks, or Streaming examples in `labs/` and `notebooks/`.

4. **Self-Healing Enhancements**:
   - If you encounter a new failure pattern (e.g., port binding collisions, stale locks, corrupted directories) that can be detected and automatically repaired by `start-services.sh` or `fix-hive.sh`, submit a PR!

---

## 🛠️ Development & Submission Workflow

1. **Fork the Repository**:
   Click the **Fork** button on GitHub.

2. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/my-cool-improvement
   ```

3. **Test Your Changes**:
   Run the verification test suite before opening a PR:
   ```bash
   bash bin/test_faults.sh
   bash bin/run_all_tests.sh
   ```

4. **Commit & Push**:
   ```bash
   git commit -m "feat: add support for Rocky Linux 9"
   git push origin feature/my-cool-improvement
   ```

5. **Open a Pull Request**:
   Submit your pull request describing what you changed, why it helps students, and how you tested it.

---

## 📜 Code of Conduct

Please review and adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Be supportive, welcoming, and constructive.
