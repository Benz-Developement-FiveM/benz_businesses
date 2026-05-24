-- Example Qbox jobs.

burgershot = {
    label = 'Burger Shot',
    type = 'restaurant',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Trainee', payment = 50 },
        [1] = { name = 'Employee', payment = 75 },
        [2] = { name = 'Cook', payment = 100 },
        [3] = { name = 'Manager', payment = 125 },
        [4] = { name = 'Owner', payment = 150, isboss = true },
    },
},

bahama = {
    label = 'Bahama Mamas',
    type = 'nightclub',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Staff', payment = 50 },
        [1] = { name = 'Bartender', payment = 75 },
        [2] = { name = 'DJ', payment = 100 },
        [3] = { name = 'Manager', payment = 125 },
        [4] = { name = 'Owner', payment = 150, isboss = true },
    },
},

vanilla = {
    label = 'Vanilla Unicorn',
    type = 'stripclub',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Staff', payment = 50 },
        [1] = { name = 'Bartender', payment = 75 },
        [2] = { name = 'Security', payment = 100 },
        [3] = { name = 'Manager', payment = 125 },
        [4] = { name = 'Owner', payment = 150, isboss = true },
    },
},
