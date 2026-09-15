import './App.css'
import AlertRow from "./AlertRow.jsx"
import {useState, useEffect} from 'react'

function App() {
    const [alerts, setAlerts] = useState([])
    const [loginStatus, setLoginStatus] = useState("loading")
    const [email, setEmail] = useState("")
    const [password, setPassword] = useState("")
    const [errorMessage, setErrorMessage] = useState(null)

    useEffect(() => {
        if (loginStatus !== "loading") {
            return;
        }
        const loadAlerts = async () => {
            try {
                const res = await fetch('http://localhost:8000/alerts', {credentials: 'include'})
                if (res.status === 401) {
                    setLoginStatus("logged_out");
                    return
                } else if (!res.ok) {
                    throw new Error(`Fetch alert failed ${res.status}`);
                }
                const data = await res.json()
                setAlerts(data);
                setLoginStatus("logged_in")
            } catch (err) {
                console.error("Can't reach the server: ", err);
                setLoginStatus("unavailable")
                setErrorMessage("Can't reach the server")
            }
        }
        loadAlerts()
    }, [loginStatus])


    const handleLogin = async () => {
        setErrorMessage(null)
        try {
            const res = await
                fetch('http://localhost:8000/auth/login', {
                    method: 'POST', headers:
                        {
                            'Content-Type':
                                'application/json',
                        }
                    ,
                    credentials: 'include',
                    body:
                        JSON.stringify({email, password}),
                })
            if (res.status === 401) {
                setErrorMessage("Email or password do not match our records")
                return
            } else if (!res.ok) {
                throw new Error(`HTTP error! status: ${res.status}`)
            }
            const data = await res.json()
            console.log('Login successful: ', data);
            setLoginStatus("loading")
        } catch (err) {
            console.error('Login failed: ', err)
            setErrorMessage("Login failed, try again")
        }
    }

    const handleLogout = async () => {
        setErrorMessage(null)
        try {
            const res = await fetch('http://localhost:8000/auth/logout', {
                method: 'POST', credentials: 'include'
            })

            if (!res.ok) {
                throw new Error(`HTTP error! status: ${res.status}`)
            }
            const data = await res.json()
            console.log('Logout successful: ', data);
            setLoginStatus("logged_out");
            setAlerts([])
        } catch (err) {
            console.error('Logout failed:', err)
            setErrorMessage("Logout failed, try again")
        }
    }

    const handleRetry = () => {
        setErrorMessage(null);
        setLoginStatus("loading")
    }

    const handleTriaged = (updatedAlert) => {
        setAlerts(prev => prev.map(
            alert => (alert.id === updatedAlert.id ? updatedAlert : alert)
        ))
    }

    if (loginStatus === "loading") {
        return (
            <p>Loading</p>
        )
    }

    if (loginStatus === "unavailable") {
        return (
            <>
                <p>{errorMessage}</p>
                <button type="button" onClick={handleRetry}>Retry</button>
            </>
        )
    }

    return (
        <>
            <h1>watchfloor</h1>
            {errorMessage && <p>{errorMessage}</p>}
            {loginStatus === "logged_in" ? (
                <>
                    <div>
                        <button type="button" onClick={handleLogout}>Logout</button>
                        <ul>
                            {alerts.map((alert) => (
                                <AlertRow key={alert.id} alert={alert} onTriaged={handleTriaged}/>
                            ))}
                        </ul>
                    </div>
                </>
            ) : (
                <>
                    <div>
                        <input value={email} onChange={e => setEmail(e.target.value)}
                               placeholder="email"/>
                        <input value={password} type="password" onChange={p => setPassword(p.target.value)}
                               placeholder="password"/>
                    </div>
                    <button type="button" onClick={handleLogin}>Login</button>
                </>
            )
            }
        </>
    );
}

export default App
