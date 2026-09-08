import './App.css'

const alerts = [{id: 1, device_name: "tc0fw", severity: "P2", status: "new"},
    {id: 2, device_name: "exhost1", severity: "P1", status: "new"}]

function App() {

    return (
        <>
            <h1>watchfloor</h1>
            <ul>
            </ul>
        </>
    )
}

function AlertRow() {

    return (
        {alerts.map((alert) => (
                <li key={alert.id}>{alert.id} - {alert.device_name} - {alert.severity} - {alert.status}</li>
            ))
        }
    )
}

export default App
