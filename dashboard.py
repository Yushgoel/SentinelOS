import streamlit as st
import json
import time
import pandas as pd
import plotly.express as px
from datetime import datetime
import os

st.set_page_config(page_title="Self-Healing Linux Dashboard", layout="wide")
st.title("Self-Healing Linux Dashboard")

# Initialize session state for historical memory data
if 'memory_history' not in st.session_state:
    st.session_state.memory_history = []

def load_latest_data():
    """Load the latest data from the daemon's status file"""
    try:
        with open('/var/log/self-healing/status.json', 'r') as f:
            return json.load(f)
    except Exception as e:
        return None

def load_recent_diagnoses():
    """Load recent Claude diagnoses from log files"""
    diagnoses = []
    log_dir = "/var/log/self-healing"
    try:
        for filename in sorted(os.listdir(log_dir), reverse=True):  # Get all files
            if filename.endswith('.log') and not filename == 'daemon.log':
                with open(os.path.join(log_dir, filename), 'r') as f:
                    content = f.read()
                    # Extract timestamp from filename, handling both service and memory logs
                    parts = filename.split('_')
                    if len(parts) >= 2:
                        try:
                            # Try to parse the timestamp portion
                            timestamp_str = '_'.join(parts[1:]).split('.')[0]
                            timestamp = datetime.strptime(timestamp_str, '%Y%m%d_%H%M%S')
                            
                            # Extract the diagnosis section
                            diagnosis_section = ""
                            if '=== DIAGNOSIS ===' in content:
                                diagnosis_section = content.split('=== DIAGNOSIS ===')[1].split('===')[0].strip()
                            
                            # Extract actions/commands if present
                            actions_section = ""
                            if '=== FIX COMMAND:' in content:
                                actions_section = content.split('=== FIX COMMAND:')[1].split('===')[0].strip()
                            elif 'ACTIONS:' in content:
                                actions_section = content.split('ACTIONS:')[1].split('EXPLANATION:')[0].strip()

                            diagnoses.append({
                                'timestamp': timestamp,
                                'diagnosis': diagnosis_section,
                                'actions': actions_section,
                                'full_content': content
                            })
                        except ValueError:
                            continue  # Skip files with invalid timestamp format
        
        # Sort by timestamp and keep 10 most recent
        diagnoses.sort(key=lambda x: x['timestamp'], reverse=True)
        return diagnoses[:10]
    except Exception as e:
        st.error(f"Error loading diagnoses: {e}")
    return diagnoses

# Create layout
col1, col2 = st.columns([2, 1])

# Main dashboard update loop
if True:  # Replace while loop with if True for Streamlit
    data = load_latest_data()
    
    if data:
        with col1:
            # Memory Usage Graph
            st.subheader("Memory Usage Over Time")
            
            # Update memory history
            st.session_state.memory_history.append({
                'timestamp': datetime.now(),
                'usage': data['memory_usage']
            })
            
            # Keep last 100 data points
            if len(st.session_state.memory_history) > 100:
                st.session_state.memory_history.pop(0)
            
            # Create DataFrame and plot
            df = pd.DataFrame(st.session_state.memory_history)
            fig = px.line(df, x='timestamp', y='usage', 
                         title='Memory Usage %',
                         labels={'usage': 'Usage %', 'timestamp': 'Time'})
            fig.update_yaxes(range=[0, 100])  # Fix y-axis range from 0 to 100
            fig.update_traces(line_shape='spline', line_smoothing=0.8)  # Add smoothing
            st.plotly_chart(fig, use_container_width=True)
            
            # Top Memory Processes
            st.subheader("Top Memory-Consuming Processes")
            if 'top_processes' in data:
                st.code(data['top_processes'])
        
        with col2:
            # Recent Claude Diagnoses
            st.subheader("Recent AI Diagnoses")
            diagnoses = load_recent_diagnoses()
            for diagnosis in diagnoses:
                with st.expander(f"Diagnosis from {diagnosis['timestamp'].strftime('%Y-%m-%d %H:%M:%S')}"):
                    if diagnosis['diagnosis']:
                        st.markdown("**AI Diagnosis:**")
                        st.text(diagnosis['diagnosis'])
                    if diagnosis['actions']:
                        st.markdown("**Recommended Actions:**")
                        st.text(diagnosis['actions'])
                    st.markdown("**Full Log:**")
                    st.text(diagnosis['full_content'])
    
    time.sleep(2)  # Update every 2 seconds
    st.rerun()  # Use st.rerun() instead of experimental_rerun()