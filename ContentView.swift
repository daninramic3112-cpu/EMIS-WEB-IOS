
import SwiftUI

// MARK: - EMIS MODELS

let classes = [
    "I-A", "I-B", "II-A", "II-B", "III-A", "III-B",
    "IV-A", "IV-B", "V-A", "V-B", "VI-A", "VI-B",
    "VII-A", "VII-B", "VIII-A", "VIII-B", "IX-A", "IX-B"
]

let subjects = [
    "Matematika", "Bosanski jezik", "Engleski jezik",
    "Historija", "Geografija", "Fizika", "Hemija",
    "Biologija", "Informatika", "Likovna kultura",
    "Muzička kultura", "Tjelesni odgoj"
]

struct Grade: Codable, Identifiable {
    var id = UUID()
    var subject: String
    var value: Int
    var date: String
}

struct Comment: Codable, Identifiable {
    var id = UUID()
    var text: String
    var date: String
}

struct Lesson: Codable, Identifiable {
    var id = UUID()
    var classroom: String
    var subject: String
    var topic: String
    var date: String
    var number: Int
    var note: String
}

struct Student: Codable, Identifiable {
    var id: String
    var name: String
    var password: String
    var classroom: String
    var grades: [Grade] = []
    var comments: [Comment] = []
    var absences: Int = 0

    var average: Double {
        guard !grades.isEmpty else { return 0 }
        return Double(grades.map(\.value).reduce(0,+)) /
            Double(grades.count)
    }
}

struct SchoolDatabase: Codable {
    var students: [Student] = []
    var lessons: [Lesson] = []
}

// MARK: - DATABASE

@MainActor
final class EMISData: ObservableObject {
    @Published var database: SchoolDatabase
    @Published var username: String?
    @Published var isTeacher = false
    @Published var selectedClass = "I-A"

    private var file: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("emis_database.json")
    }

    init() {
        if let data = try? Data(contentsOf: file),
           let saved = try? JSONDecoder().decode(
               SchoolDatabase.self, from: data
           ) {
            database = saved
        } else {
            database = Self.createDatabase()
            save()
        }
    }

    static func createDatabase() -> SchoolDatabase {
        let firstNames = [
            "Amar","Adnan","Haris","Emir","Tarik",
            "Dino","Emin","Armin","Kerim","Anes",
            "Nedim","Aldin","Mirza","Hamed","Hamza",
            "Ahmed","Faruk","Faris","Imran","Ajdin",
            "Amina","Lejla","Sara","Hana","Emina",
            "Lamija","Merjem","Ajla","Iman","Esma",
            "Nejla","Belma","Amna","Dina","Mia",
            "Una","Nina","Elma","Selma","Alma"
        ]

        let lastNames = [
            "Hodžić","Kovačević","Hadžić",
            "Begić","Mujkić","Ramić","Delić"
        ]

        var result = SchoolDatabase()
        var number = 1

        for classroom in classes {
            for index in 0..<25 {
                let name =
                    "\(firstNames[(number - 1) % firstNames.count]) " +
                    "\(lastNames[(number - 1) % lastNames.count])"

                result.students.append(
                    Student(
                        id: String(format: "U%04d", number),
                        name: name,
                        password: "skola123",
                        classroom: classroom
                    )
                )
                number += 1
            }
        }

        return result
    }

    func save() {
        if let data = try? JSONEncoder().encode(database) {
            try? data.write(to: file, options: .atomic)
        }
    }

    var currentStudent: Student? {
        database.students.first { $0.id == username }
    }

    func studentsInClass() -> [Student] {
        database.students.filter {
            $0.classroom == selectedClass
        }
    }

    func update(_ student: Student) {
        guard let index = database.students.firstIndex(
            where: { $0.id == student.id }
        ) else { return }

        database.students[index] = student
        save()
    }

    func login(
        name: String,
        password: String,
        teacher: Bool,
        classroom: String
    ) -> String? {
        if teacher {
            guard name == "Danin",
                  password == "rsjebosna" else {
                return "Pogrešno korisničko ime ili lozinka."
            }

            username = "Danin"
            isTeacher = true
            selectedClass = classroom
            return nil
        }

        guard let student = database.students.first(
            where: { $0.id.lowercased() == name.lowercased() }
        ) else {
            return "Učenik nije pronađen."
        }

        guard student.password == password else {
            return "Pogrešna lozinka."
        }

        guard student.classroom == classroom else {
            return "Pogrešno odjeljenje."
        }

        username = student.id
        isTeacher = false
        selectedClass = classroom
        return nil
    }

    func logout() {
        username = nil
        isTeacher = false
    }

    func addGrade(
        studentID: String,
        subject: String,
        value: Int
    ) {
        guard var student = database.students.first(
            where: { $0.id == studentID }
        ) else { return }

        student.grades.append(
            Grade(
                subject: subject,
                value: value,
                date: Date.now.formatted(date: .numeric, time: .omitted)
            )
        )

        update(student)
    }

    func addComment(studentID: String, text: String) {
        guard var student = database.students.first(
            where: { $0.id == studentID }
        ) else { return }

        student.comments.append(
            Comment(
                text: text,
                date: Date.now.formatted(date: .numeric, time: .omitted)
            )
        )

        update(student)
    }

    func addAbsence(studentID: String) {
        guard var student = database.students.first(
            where: { $0.id == studentID }
        ) else { return }

        student.absences += 1
        update(student)
    }

    func addLesson(_ lesson: Lesson) {
        database.lessons.append(lesson)
        save()
    }
}

// MARK: - ROOT

struct RootView: View {
    @StateObject private var data = EMISData()

    var body: some View {
        Group {
            if data.username == nil {
                LoginView()
            } else {
                DashboardView()
            }
        }
        .environmentObject(data)
        .tint(.blue)
    }
}

// MARK: - LOGIN

struct LoginView: View {
    @EnvironmentObject var data: EMISData

    @State private var name = ""
    @State private var password = ""
    @State private var teacher = true
    @State private var classroom = "I-A"
    @State private var error = ""

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 25) {
                    Spacer(minLength: 45)

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 65))
                        .foregroundStyle(.white)
                        .frame(width: 110, height: 110)
                        .background(.blue.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 28))

                    VStack(spacing: 5) {
                        Text("EMIS")
                            .font(.system(size: 42, weight: .black))

                        Text("ELEKTRONSKI ŠKOLSKI DNEVNIK")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Vrsta naloga", selection: $teacher) {
                            Text("Nastavnik").tag(true)
                            Text("Učenik").tag(false)
                        }
                        .pickerStyle(.segmented)

                        if !teacher {
                            Picker("Odjeljenje", selection: $classroom) {
                                ForEach(classes, id: \.self) {
                                    Text($0).tag($0)
                                }
                            }
                        }

                        TextField(
                            teacher ? "Korisničko ime" : "Učenički ID",
                            text: $name
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                        SecureField("Lozinka", text: $password)
                            .textFieldStyle(.roundedBorder)

                        if !error.isEmpty {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }

                        Button {
                            error = data.login(
                                name: name,
                                password: password,
                                teacher: teacher,
                                classroom: classroom
                            ) ?? ""
                        } label: {
                            Text("PRIJAVI SE")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(22)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    Text("EMIS • iPhone izdanje")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(22)
            }
        }
    }
}

// MARK: - DASHBOARD

struct DashboardView: View {
    @EnvironmentObject var data: EMISData
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Label("Početna", systemImage: "house.fill")
                }
                .tag(0)

            StudentsView()
                .tabItem {
                    Label("Učenici", systemImage: "person.3.fill")
                }
                .tag(1)

            GradesView()
                .tabItem {
                    Label("Ocjene", systemImage: "list.number")
                }
                .tag(2)

            LessonsView()
                .tabItem {
                    Label("Časovi", systemImage: "calendar")
                }
                .tag(3)

            CommentsView()
                .tabItem {
                    Label("Komentari", systemImage: "text.bubble")
                }
                .tag(4)

            AbsencesView()
                .tabItem {
                    Label("Izostanci", systemImage: "calendar.badge.exclamationmark")
                }
                .tag(5)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    data.logout()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }
}

// MARK: - HOME

struct HomeView: View {
    @EnvironmentObject var data: EMISData

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Dobro došao, \(data.isTeacher ? "Danin" : data.currentStudent?.name ?? "")")
                        .font(.title2.bold())

                    if data.isTeacher {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 12
                        ) {
                            StatCard(
                                title: "Učenici",
                                value: "\(data.database.students.count)",
                                icon: "person.3.fill"
                            )

                            StatCard(
                                title: "Odjeljenja",
                                value: "18",
                                icon: "building.2.fill"
                            )

                            StatCard(
                                title: "Časovi",
                                value: "\(data.database.lessons.count)",
                                icon: "calendar"
                            )

                            StatCard(
                                title: "Ocjene",
                                value: "\(data.database.students.reduce(0) { $0 + $1.grades.count })",
                                icon: "list.number"
                            )
                        }

                        Text("Odjeljenje")
                            .font(.headline)

                        Picker("Odjeljenje", selection: $data.selectedClass) {
                            ForEach(classes, id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .pickerStyle(.menu)

                        ForEach(data.studentsInClass()) { student in
                            StudentCard(student: student)
                        }
                    } else if let student = data.currentStudent {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 12
                        ) {
                            StatCard(
                                title: "Odjeljenje",
                                value: student.classroom,
                                icon: "building.2"
                            )

                            StatCard(
                                title: "Prosjek",
                                value: String(format: "%.2f", student.average),
                                icon: "chart.bar"
                            )

                            StatCard(
                                title: "Ocjene",
                                value: "\(student.grades.count)",
                                icon: "list.number"
                            )

                            StatCard(
                                title: "Izostanci",
                                value: "\(student.absences)",
                                icon: "calendar.badge.exclamationmark"
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("EMIS")
        }
    }
}

struct StatCard: View {
    var title: String
    var value: String
    var icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 17))
    }
}

struct StudentCard: View {
    var student: Student

    var body: some View {
        HStack {
            Image(systemName: "person.crop.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)

            VStack(alignment: .leading) {
                Text(student.name).fontWeight(.semibold)
                Text(student.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(String(format: "%.2f", student.average))
                    .fontWeight(.bold)
                Text("\(student.absences) izost.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - STUDENTS

struct StudentsView: View {
    @EnvironmentObject var data: EMISData

    var body: some View {
        NavigationStack {
            List {
                Picker("Odjeljenje", selection: $data.selectedClass) {
                    ForEach(classes, id: \.self) {
                        Text($0).tag($0)
                    }
                }

                ForEach(data.studentsInClass()) { student in
                    NavigationLink {
                        StudentDetailView(studentID: student.id)
                    } label: {
                        StudentCard(student: student)
                    }
                }
            }
            .navigationTitle("Učenici")
        }
    }
}

struct StudentDetailView: View {
    @EnvironmentObject var data: EMISData
    var studentID: String

    var student: Student? {
        data.database.students.first { $0.id == studentID }
    }

    var body: some View {
        List {
            if let student {
                Section("Podaci") {
                    LabeledContent("Ime", value: student.name)
                    LabeledContent("ID", value: student.id)
                    LabeledContent("Odjeljenje", value: student.classroom)
                    LabeledContent("Prosjek", value: String(format: "%.2f", student.average))
                    LabeledContent("Izostanci", value: "\(student.absences)")
                }

                Section("Ocjene") {
                    ForEach(student.grades) { grade in
                        HStack {
                            Text(grade.subject)
                            Spacer()
                            Text("\(grade.value)")
                                .fontWeight(.bold)
                            Text(grade.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Komentari") {
                    ForEach(student.comments) { comment in
                        VStack(alignment: .leading) {
                            Text(comment.text)
                            Text(comment.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Profil učenika")
    }
}

// MARK: - GRADES

struct GradesView: View {
    @EnvironmentObject var data: EMISData
    @State private var showForm = false

    var body: some View {
        NavigationStack {
            List {
                if data.isTeacher {
                    ForEach(data.studentsInClass()) { student in
                        NavigationLink {
                            StudentDetailView(studentID: student.id)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(student.name)
                                Text("Prosjek: \(String(format: "%.2f", student.average))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if let student = data.currentStudent {
                    Section {
                        LabeledContent("Prosjek", value: String(format: "%.2f", student.average))
                        LabeledContent("Broj ocjena", value: "\(student.grades.count)")
                    }

                    ForEach(student.grades) { grade in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(grade.subject)
                                Text(grade.date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(grade.value)")
                                .font(.title2.bold())
                                .foregroundStyle(grade.value < 3 ? .red : .blue)
                        }
                    }
                }
            }
            .navigationTitle("Ocjene")
            .toolbar {
                if data.isTeacher {
                    Button {
                        showForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showForm) {
                GradeForm()
            }
        }
    }
}

struct GradeForm: View {
    @EnvironmentObject var data: EMISData
    @Environment(\.dismiss) var dismiss

    @State private var classroom = "I-A"
    @State private var studentID = ""
    @State private var subject = subjects[0]
    @State private var grade = 5

    var body: some View {
        NavigationStack {
            Form {
                Picker("Odjeljenje", selection: $classroom) {
                    ForEach(classes, id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .onChange(of: classroom) { _, _ in
                    studentID = data.database.students.first {
                        $0.classroom == classroom
                    }?.id ?? ""
                }

                Picker("Učenik", selection: $studentID) {
                    ForEach(data.database.students.filter {
                        $0.classroom == classroom
                    }) {
                        Text($0.name).tag($0.id)
                    }
                }

                Picker("Predmet", selection: $subject) {
                    ForEach(subjects, id: \.self) {
                        Text($0).tag($0)
                    }
                }

                Picker("Ocjena", selection: $grade) {
                    ForEach(1...5, id: \.self) {
                        Text("\($0)").tag($0)
                    }
                }
            }
            .navigationTitle("Nova ocjena")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Sačuvaj") {
                        if !studentID.isEmpty {
                            data.addGrade(
                                studentID: studentID,
                                subject: subject,
                                value: grade
                            )
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                studentID = data.database.students.first {
                    $0.classroom == classroom
                }?.id ?? ""
            }
        }
    }
}

// MARK: - LESSONS

struct LessonsView: View {
    @EnvironmentObject var data: EMISData
    @State private var showForm = false

    var visibleLessons: [Lesson] {
        if data.isTeacher {
            return data.database.lessons
        }

        return data.database.lessons.filter {
            $0.classroom == data.currentStudent?.classroom
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleLessons.reversed()) { lesson in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(lesson.subject).font(.headline)
                            Spacer()
                            Text(lesson.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("\(lesson.classroom) • \(lesson.number). čas")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(lesson.topic)

                        if !lesson.note.isEmpty {
                            Text(lesson.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("Časovi")
            .toolbar {
                if data.isTeacher {
                    Button {
                        showForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showForm) {
                LessonForm()
            }
        }
    }
}

struct LessonForm: View {
    @EnvironmentObject var data: EMISData
    @Environment(\.dismiss) var dismiss

    @State private var classroom = "I-A"
    @State private var subject = subjects[0]
    @State private var topic = ""
    @State private var note = ""
    @State private var number = 1
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Picker("Odjeljenje", selection: $classroom) {
                    ForEach(classes, id: \.self) {
                        Text($0).tag($0)
                    }
                }

                Picker("Predmet", selection: $subject) {
                    ForEach(subjects, id: \.self) {
                        Text($0).tag($0)
                    }
                }

                DatePicker("Datum", selection: $date, displayedComponents: .date)

                Picker("Redni broj časa", selection: $number) {
                    ForEach(1...8, id: \.self) {
                        Text("\($0)").tag($0)
                    }
                }

                TextField("Nastavna jedinica", text: $topic)
                TextField("Napomena", text: $note)
            }
            .navigationTitle("Novi čas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Sačuvaj") {
                        guard !topic.isEmpty else { return }

                        data.addLesson(
                            Lesson(
                                classroom: classroom,
                                subject: subject,
                                topic: topic,
                                date: date.formatted(date: .numeric, time: .omitted),
                                number: number,
                                note: note
                            )
                        )

                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - COMMENTS

struct CommentsView: View {
    @EnvironmentObject var data: EMISData
    @State private var showForm = false

    var body: some View {
        NavigationStack {
            List {
                if data.isTeacher {
                    ForEach(data.database.students) { student in
                        ForEach(student.comments) { comment in
                            VStack(alignment: .leading) {
                                Text(student.name).font(.headline)
                                Text(comment.text)
                                Text(comment.date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if let student = data.currentStudent {
                    ForEach(student.comments) { comment in
                        VStack(alignment: .leading) {
                            Text(comment.text)
                            Text(comment.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Komentari")
            .toolbar {
                if data.isTeacher {
                    Button {
                        showForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showForm) {
                CommentForm()
            }
        }
    }
}

struct CommentForm: View {
    @EnvironmentObject var data: EMISData
    @Environment(\.dismiss) var dismiss

    @State private var classroom = "I-A"
    @State private var studentID = ""
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Odjeljenje", selection: $classroom) {
                    ForEach(classes, id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .onChange(of: classroom) { _, _ in
                    studentID = data.database.students.first {
                        $0.classroom == classroom
                    }?.id ?? ""
                }

                Picker("Učenik", selection: $studentID) {
                    ForEach(data.database.students.filter {
                        $0.classroom == classroom
                    }) {
                        Text($0.name).tag($0.id)
                    }
                }

                Section("Komentar") {
                    TextEditor(text: $text)
                        .frame(minHeight: 130)
                }
            }
            .navigationTitle("Novi komentar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Objavi") {
                        if !studentID.isEmpty && !text.isEmpty {
                            data.addComment(
                                studentID: studentID,
                                text: text
                            )
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                studentID = data.database.students.first {
                    $0.classroom == classroom
                }?.id ?? ""
            }
        }
    }
}

// MARK: - ABSENCES

struct AbsencesView: View {
    @EnvironmentObject var data: EMISData
    @State private var showForm = false

    var body: some View {
        NavigationStack {
            List {
                if data.isTeacher {
                    ForEach(data.database.students) { student in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(student.name)
                                Text(student.classroom)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(student.absences)")
                                .font(.title3.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                } else if let student = data.currentStudent {
                    LabeledContent(
                        "Ukupno izostanaka",
                        value: "\(student.absences)"
                    )
                }
            }
            .navigationTitle("Izostanci")
            .toolbar {
                if data.isTeacher {
                    Button {
                        showForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showForm) {
                AbsenceForm()
            }
        }
    }
}

struct AbsenceForm: View {
    @EnvironmentObject var data: EMISData
    @Environment(\.dismiss) var dismiss

    @State private var classroom = "I-A"
    @State private var studentID = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Odjeljenje", selection: $classroom) {
                    ForEach(classes, id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .onChange(of: classroom) { _, _ in
                    studentID = data.database.students.first {
                        $0.classroom == classroom
                    }?.id ?? ""
                }

                Picker("Učenik", selection: $studentID) {
                    ForEach(data.database.students.filter {
                        $0.classroom == classroom
                    }) {
                        Text($0.name).tag($0.id)
                    }
                }
            }
            .navigationTitle("Izostanak")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Evidentiraj") {
                        if let student = data.database.students.first(
                            where: { $0.id == studentID }
                        ) {
                            data.addAbsence(studentID: student.id)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                studentID = data.database.students.first {
                    $0.classroom == classroom
                }?.id ?? ""
            }
        }
    }
}
