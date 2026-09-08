import './App.css'
import AlertRow from "./AlertRow.jsx"

const alerts = [{id: 1, device_name: "tc0fw", severity: "P2", status: "new"},
    {id: 2, device_name: "exhost1", severity: "P1", status: "new"}]

function App() {

    return (
        <>
            <h1>watchfloor</h1>
            <ul>
                {alerts.map((alert) => (
                    <AlertRow key={alert.id} alert={alert} />
                ))}
            </ul>
        </>
    )
}

export default App
