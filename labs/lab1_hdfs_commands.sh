# ============================================================================
# Lab 1: HDFS Basic Commands
# ============================================================================
# Aim: To learn and practice basic Hadoop HDFS commands for file and directory
#      operations including create, upload, download, copy, move, delete, and
#      permissions management in a single-node Hadoop cluster.
#
# Prerequisites:
#   - Hadoop 3.x installed and configured
#   - HDFS running (start-dfs.sh)
#   - JAVA_HOME and HADOOP_HOME set in ~/.bashrc
#
# Procedure: Execute the commands below one by one in the terminal.
# ============================================================================

# --- Step 1: Verify HDFS is running ---
jps
# Expected: NameNode, DataNode, SecondaryNameNode (on pseudo-distributed mode)

hdfs dfsadmin -report
# Expected: Summary showing Live datanodes: 1

# --- Step 2: Check the HDFS filesystem root ---
hdfs dfs -ls /
# Expected: /user directory

# --- Step 3: Create directories in HDFS ---
hdfs dfs -mkdir /lab1
hdfs dfs -mkdir /lab1/data
hdfs dfs -mkdir -p /lab1/data/subdir1
hdfs dfs -mkdir -p /lab1/data/subdir2
hdfs dfs -ls /lab1/

# --- Step 4: Check directory permissions ---
hdfs dfs -ls -la /lab1/
# Expected: drwxr-xr-x permissions for hdfs superuser

# --- Step 5: Create a local file to upload ---
mkdir -p /tmp/hdfs_lab
echo "Row1: Alice,1001,HR" > /tmp/hdfs_lab/employees.txt
echo "Row2: Bob,1002,IT" >> /tmp/hdfs_lab/employees.txt
echo "Row3: Charlie,1003,Finance" >> /tmp/hdfs_lab/employees.txt
echo "Row4: Diana,1004,HR" >> /tmp/hdfs_lab/employees.txt
echo "Row5: Eve,1005,IT" >> /tmp/hdfs_lab/employees.txt
cat /tmp/hdfs_lab/employees.txt

# --- Step 6: Upload (put) file from local to HDFS ---
hdfs dfs -put /tmp/hdfs_lab/employees.txt /lab1/data/
hdfs dfs -ls /lab1/data/

# --- Step 7: View the contents of a file in HDFS ---
hdfs dfs -cat /lab1/data/employees.txt

# --- Step 8: Get (download) file from HDFS to local ---
mkdir -p /tmp/hdfs_lab/download
hdfs dfs -get /lab1/data/employees.txt /tmp/hdfs_lab/download/
ls /tmp/hdfs_lab/download/

# --- Step 9: Copy file within HDFS (from one dir to another) ---
hdfs dfs -cp /lab1/data/employees.txt /lab1/data/subdir1/employees_copy.txt
hdfs dfs -ls /lab1/data/subdir1/

# --- Step 10: Move file within HDFS ---
hdfs dfs -mkdir /lab1/archive
hdfs dfs -mv /lab1/data/subdir1/employees_copy.txt /lab1/archive/
hdfs dfs -ls /lab1/archive/

# --- Step 11: Check file size and count ---
hdfs dfs -du -s /lab1/data/employees.txt
hdfs dfs -du -h /lab1/data/

# --- Step 12: Check HDFS disk usage summary ---
hdfs dfs -du -s -h /

# --- Step 13: Count files and directories ---
hdfs dfs -count /lab1/

# --- Step 14: Create multiple local files and upload as a directory ---
echo "Product: Laptop,Price:999" > /tmp/hdfs_lab/products.txt
echo "Product: Mouse,Price:25" >> /tmp/hdfs_lab/products.txt
echo "Product: Keyboard,Price:50" >> /tmp/hdfs_lab/products.txt

hdfs dfs -put /tmp/hdfs_lab/products.txt /lab1/data/
hdfs dfs -ls /lab1/data/

# --- Step 15: Use -getmerge to download a directory as single file ---
hdfs dfs -getmerge /lab1/data/ /tmp/hdfs_lab/all_data_merged.txt
cat /tmp/hdfs_lab/all_data_merged.txt

# --- Step 16: Check if a file or directory exists in HDFS ---
hdfs dfs -test -e /lab1/data/employees.txt && echo "File exists" || echo "File does not exist"
hdfs dfs -test -d /lab1/data/ && echo "Directory exists" || echo "Not a directory"
hdfs dfs -test -f /lab1/data/employees.txt && echo "Is a file" || echo "Not a file"

# --- Step 17: Touch (create empty file) in HDFS ---
hdfs dfs -touch /lab1/data/empty_file.txt
hdfs dfs -ls /lab1/data/empty_file.txt

# --- Step 18: Append content to an HDFS file ---
echo "Row6: Frank,1006,Finance" | hdfs dfs -appendToFile - /lab1/data/employees.txt
hdfs dfs -cat /lab1/data/employees.txt

# --- Step 19: Change permissions in HDFS ---
hdfs dfs -chmod 755 /lab1/
hdfs dfs -chmod -R 644 /lab1/data/
hdfs dfs -ls -la /lab1/

# --- Step 20: Change owner and group in HDFS (requires sudo) ---
# sudo -u hdfs hdfs dfs -chown hdfs:hdfs /lab1/data/employees.txt

# --- Step 21: Tail (view last 1KB of a file) in HDFS ---
hdfs dfs -tail /lab1/data/employees.txt

# --- Step 22: Find files in HDFS matching a pattern ---
hdfs dfs -find /lab1/ -name "*.txt"

# --- Step 23: Stat (file status) in HDFS ---
hdfs dfs -stat /lab1/data/employees.txt

# --- Step 24: Truncate a file in HDFS ---
hdfs dfs -truncate -w 0 /lab1/data/empty_file.txt
hdfs dfs -cat /lab1/data/empty_file.txt

# --- Step 25: Delete files and directories from HDFS ---
hdfs dfs -rm /lab1/data/empty_file.txt
hdfs dfs -rm -r /lab1/archive/
hdfs dfs -rm -r /lab1/data/subdir2/
hdfs dfs -ls -R /lab1/

# --- Cleanup (optional) ---
# hdfs dfs -rm -r /lab1/
# rm -rf /tmp/hdfs_lab

# ============================================================================
# End of Lab 1
# ============================================================================
