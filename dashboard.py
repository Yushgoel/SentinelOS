import streamlit as st
import json
import time
import pandas as pd
import plotly.express as px
from datetime import datetime
import os

st.set_page_config(
    page_title="SentinelOS Telemetry",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Add custom CSS for better styling
st.markdown("""
    <style>
    .main {
        padding: 2rem;
    }
    .stTitle {
        color: #2E4B7C;
        font-size: 2.5rem !important;
        padding-bottom: 2rem;
    }
    .stSubheader {
        color: #1E325C;
        padding-top: 1rem;
    }
    .streamlit-expanderHeader {
        background-color: #f0f2f6;
        border-radius: 5px;
    }
    </style>
""", unsafe_allow_html=True)

st.title("SentinelOS Telemetry")

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

# Create layout with adjusted ratio (previously [2, 1])
col1, col2 = st.columns([3, 2])

# Main dashboard update loop
if True:  # Replace while loop with if True for Streamlit
    data = load_latest_data()
    
    if data:
        with col1:
            # Memory Usage Graph
            st.subheader("Memory Usage Over Time")
            
            # Update memory history with timestamp
            current_time = datetime.now()
            st.session_state.memory_history.append({
                'timestamp': current_time,
                'usage': data['memory_usage']
            })
            
            # Keep only last 15 minutes of data
            fifteen_mins_ago = current_time.timestamp() - 900  # 15 minutes in seconds
            st.session_state.memory_history = [
                entry for entry in st.session_state.memory_history 
                if entry['timestamp'].timestamp() > fifteen_mins_ago
            ]
            
            # Create DataFrame and plot
            df = pd.DataFrame(st.session_state.memory_history)
            
            # Convert timestamps to relative minutes ago
            if len(df) > 0:
                df['minutes_ago'] = (current_time - df['timestamp']).dt.total_seconds() / 60
            
            fig = px.line(df, x='minutes_ago', y='usage',
                         title='Memory Usage % (Last 15 Minutes)',
                         labels={'usage': 'Usage %', 'minutes_ago': 'Minutes Ago'})
            
            fig.update_layout(
                xaxis_range=[15, 0],  # Show 15 to 0 minutes ago, reversed
                yaxis_range=[0, 100],
                margin=dict(t=30, b=30),  # Reduce top and bottom margins
                xaxis_title="Time (minutes ago)"
            )
            fig.update_traces(line_shape='spline', line_smoothing=0.8)
            st.plotly_chart(fig, use_container_width=True)
            
            # Top Memory Processes
            st.subheader("Top Memory-Consuming Processes")
            if 'top_processes' in data:
                st.code(data['top_processes'])
        
        with col2:
            # Recent Claude Diagnoses
            st.subheader("🔧 Claude's System Patches")
            diagnoses = load_recent_diagnoses()
            if diagnoses:
                for diagnosis in diagnoses:
                    status_color = "🟢" if diagnosis['actions'] else "🟡"
                    with st.expander(f"{status_color} Patch applied at {diagnosis['timestamp'].strftime('%Y-%m-%d %H:%M:%S')}"):
                        if diagnosis['diagnosis']:
                            st.markdown("**📊 System Analysis:**")
                            st.markdown(f"```\n{diagnosis['diagnosis']}\n```")
                        if diagnosis['actions']:
                            st.markdown("**🛠️ Applied Fix:**")
                            st.markdown(f"```bash\n{diagnosis['actions']}\n```")
                        if st.button(f"View Full Log", key=f"log_{diagnosis['timestamp'].timestamp()}"):
                            st.code(diagnosis['full_content'])
            else:
                st.info("🎯 System is running smoothly - no patches needed!")
    
    time.sleep(2)  # Update every 2 seconds
    st.rerun()  # Use st.rerun() instead of experimental_rerun()