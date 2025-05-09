## 1. Set Up Python Virtual Environment

```bash
pip install --upgrade pip
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 2. Extract Frames from a Video
Add a random mp4 video to the folder
```
python3 src/extract_frames.py
```

## 3. Run the Project (Compilation + Execution)
```
chmod +x bash_scripts/*.sh
```

```
./bash_scripts/v1_serial.sh
```

```
./bash_scripts/v2_mpi.sh
```

```
./bash_scripts/v3_cuda.sh
```
```
./bash_scripts/v4_full.sh
```