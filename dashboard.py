import streamlit as st
import time
import pandas as pd
import plotly.express as px
from datetime import datetime, timedelta
import json
import os

# Set up the Streamlit page
st.set_page_config(
    page_title="System Health Dashboard",
    page_icon="🔧",
    layout="wide"
)

# Title
st.title("🔧 System Health Dashboard")

# Create three columns for the main metrics
col1, col2, col3 = st.columns(3)

# Function to create memory usage chart
def create_memory_chart(memory_history):
    if not memory_history:
        return None
    
    df = pd.DataFrame(memory_history)
    fig = px.line(
        df, 
        x='timestamp', 
        y='used_percent',
        title='Memory Usage Over Time',
        labels={'used_percent': 'Memory Usage (%)', 'timestamp': 'Time'}
    )
    fig.update_layout(
        height=400,
        showlegend=False,
        yaxis_range=[0, 100]
    )
    return fig

# Function to format process table
def format_process_table(processes):
    if not processes:
        return pd.DataFrame()
    
    columns = ['USER', 'PID', '%CPU', '%MEM', 'VSZ', 'RSS', 'TTY', 'STAT', 'START', 'TIME', 'COMMAND']
    df = pd.DataFrame(processes, columns=columns)
    return df[['USER', 'PID', '%CPU', '%MEM', 'COMMAND']]

# Function to read shared data file
def read_daemon_data():
    try:
        with open('/var/log/self-healing/dashboard_data.json', 'r') as f:
            return json.load(f)
    except Exception as e:
        st.error(f"Error reading daemon data: {str(e)}")
        return {
            'memory_history': [],
            'top_processes': [],
            'claude_thoughts': [],
            'service_status': {}
        }

# Main dashboard loop
def main():
    while True:
        # Get latest data
        data = read_daemon_data()
        
        # Memory usage chart
        with col1:
            st.subheader("Memory Usage")
            fig = create_memory_chart(data['memory_history'])
            if fig:
                st.plotly_chart(fig, use_container_width=True)
            
            current_memory = data['memory_history'][-1]['used_percent'] if data['memory_history'] else 0
            st.metric("Current Memory Usage", f"{current_memory:.1f}%")

        # Service Status
        with col2:
            st.subheader("Service Status")
            for service, status in data['service_status'].items():
                color = "🟢" if status == "active" else "🔴"
                st.write(f"{color} {service}: {status}")

        # Top Processes
        with col3:
            st.subheader("Top Memory Processes")
            df = format_process_table(data['top_processes'])
            st.dataframe(df, hide_index=True)

        # Claude's Thoughts
        st.subheader("🤖 Claude's Thoughts")
        thoughts = data['claude_thoughts']
        if thoughts:
            for thought in reversed(thoughts[-5:]):  # Show last 5 thoughts
                with st.expander(f"{thought['timestamp']} - {thought['type']}"):
                    st.text(thought['diagnosis'])

        # Wait before refreshing
        time.sleep(5)
        st.experimental_rerun()

if __name__ == "__main__":
    main() 