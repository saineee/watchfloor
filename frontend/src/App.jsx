import './App.css'
import AlertRow from "./AlertRow.jsx"
import {useState, useEffect} from 'react'

const dataFromApi = [{id: 1, device_name: "tc0fw", severity: "P2", status: "new"},
    {id: 2, device_name: "exhost1", severity: "P1", status: "new"}]

function App() {
    const [alerts, setAlerts] = useState(dataFromApi)
    useEffect(() => {
        fetch('http://localhost:8000/alerts')
            .then(res => {
                if (!res.ok) {
                    throw new Error(`HTTP error! status : ${res.status}`)
                }
                return res.json()
            })
            .then(fetchedAlerts => {
                setAlerts(fetchedAlerts)
            })
            .catch(err => console.error("Failed to fetch alerts:", err))
    }, [])
    return (
        <>
            <h1>watchfloor</h1>
            <ul>
                {alerts.map((alert) => (
                    <AlertRow key={alert.id} alert={alert}/>
                ))}
            </ul>
        </>
    )
}

export default App
