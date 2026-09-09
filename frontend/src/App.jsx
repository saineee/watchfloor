import './App.css'
import AlertRow from "./AlertRow.jsx"
import {useState, useEffect} from 'react'

function App() {
    const [alerts, setAlerts] = useState([])
    const [loginStatus, setLoginStatus] = useState("logged_out")
    const [email, setEmail] = useState("")
    const [password, setPassword] = useState("")
    useEffect(() => {
        fetch('http://localhost:8000/alerts', {credentials: 'include'})
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
    }, [loginStatus])
    const handleButtonClick = () => {
        fetch('http://localhost:8000/auth/login',
            {
                method: 'POST', headers:
                    {
                        'Content-Type':
                            'application/json',
                    }
                ,
                credentials: 'include',
                body:
                    JSON.stringify({email, password}),
            }
        ).then(res => {
            if (!res.ok) {
                throw new Error(`HTTP error! status: ${res.status}`
                )
            }
            return res.json()
        }).then(data => {
            console.log('Login successful: ', data)
            setLoginStatus("logged_in")
        }).catch(err => console.error('Login failed: ', err))
    }
    return (
        <>
            <h1>watchfloor</h1>
            <div>
                <input value={email} onChange={e => setEmail(e.target.value)}
                       placeholder="email"/>
                <input value={password} type="password" onChange={p => setPassword(p.target.value)}
                       placeholder="password"/>
            </div>
            <button type="button" onClick={handleButtonClick}>Login</button>
            <ul>
                {alerts.map((alert) => (
                    <AlertRow key={alert.id} alert={alert}/>
                ))}
            </ul>
        </>
    )
}

export default App
