from django.core.management.base import BaseCommand

from apps.courses.models import Category, Course, Module
from apps.lessons.models import Lesson
from apps.quizzes.models import Answer, Question, Quiz


class Command(BaseCommand):
    help = "Seed database with sample courses, lessons, and quizzes"

    def handle(self, *args, **options):
        # Categories
        it, _ = Category.objects.get_or_create(name="IT", defaults={"icon": "💻"})
        ai, _ = Category.objects.get_or_create(name="AI", defaults={"icon": "🤖"})
        design, _ = Category.objects.get_or_create(name="Design", defaults={"icon": "🎨"})
        school, _ = Category.objects.get_or_create(name="School", defaults={"icon": "📚"})

        # --- Course 1: Python Backend ---
        c1, _ = Course.objects.get_or_create(
            title="Python Backend Development",
            defaults={
                "description": "Learn backend development with Python and Django from scratch.",
                "category": it,
                "image": "https://upload.wikimedia.org/wikipedia/commons/c/c3/Python-logo-notext.svg",
            },
        )
        m1, _ = Module.objects.get_or_create(course=c1, title="Getting Started", defaults={"order": 1})
        m2, _ = Module.objects.get_or_create(course=c1, title="Django Basics", defaults={"order": 2})

        l1, _ = Lesson.objects.get_or_create(
            module=m1, title="What is Python?",
            defaults={"description": "Introduction to Python programming language.", "video_url": "https://www.youtube.com/watch?v=x7X9w_GIm1s", "order": 1},
        )
        l2, _ = Lesson.objects.get_or_create(
            module=m1, title="Installing Python",
            defaults={"description": "How to set up Python on your machine.", "video_url": "https://www.youtube.com/watch?v=YYXdXT2l-Gg", "order": 2},
        )
        l3, _ = Lesson.objects.get_or_create(
            module=m2, title="Django Project Setup",
            defaults={"description": "Create your first Django project.", "video_url": "https://www.youtube.com/watch?v=rHux0gMZ3Eg", "order": 1},
        )

        self._create_quiz(l1, "Python Basics Quiz", [
            ("What is Python?", [
                ("A snake", False),
                ("A programming language", True),
                ("A database", False),
                ("An operating system", False),
            ]),
            ("Who created Python?", [
                ("Guido van Rossum", True),
                ("Elon Musk", False),
                ("Mark Zuckerberg", False),
                ("Linus Torvalds", False),
            ]),
        ])

        # --- Course 2: AI Foundations ---
        c2, _ = Course.objects.get_or_create(
            title="AI Foundations",
            defaults={
                "description": "Understand the basics of Artificial Intelligence and Machine Learning.",
                "category": ai,
                "image": "https://upload.wikimedia.org/wikipedia/commons/1/10/AI_logo.png",
            },
        )
        m3, _ = Module.objects.get_or_create(course=c2, title="What is AI?", defaults={"order": 1})
        l4, _ = Lesson.objects.get_or_create(
            module=m3, title="Introduction to AI",
            defaults={"description": "Overview of artificial intelligence.", "video_url": "https://www.youtube.com/watch?v=ad79nYk2keg", "order": 1},
        )
        l5, _ = Lesson.objects.get_or_create(
            module=m3, title="Machine Learning vs AI",
            defaults={"description": "Difference between ML and AI.", "video_url": "https://www.youtube.com/watch?v=4RixMPF4xis", "order": 2},
        )

        self._create_quiz(l4, "AI Basics Quiz", [
            ("What does AI stand for?", [
                ("Artificial Intelligence", True),
                ("Automatic Integration", False),
                ("Advanced Internet", False),
            ]),
        ])

        # --- Course 3: UI/UX Design ---
        c3, _ = Course.objects.get_or_create(
            title="UI/UX Design Basics",
            defaults={
                "description": "Learn the fundamentals of user interface and experience design.",
                "category": design,
                "image": "https://upload.wikimedia.org/wikipedia/commons/a/ad/Figma-1-logo.png",
            },
        )
        m4, _ = Module.objects.get_or_create(course=c3, title="Design Principles", defaults={"order": 1})
        Lesson.objects.get_or_create(
            module=m4, title="What is UX?",
            defaults={"description": "Understanding user experience.", "video_url": "https://www.youtube.com/watch?v=ziQEqGZB8GE", "order": 1},
        )

        self.stdout.write(self.style.SUCCESS("Seed data created successfully!"))

    def _create_quiz(self, lesson, title, questions_data):
        quiz, _ = Quiz.objects.get_or_create(lesson=lesson, defaults={"title": title})
        for i, (text, answers_data) in enumerate(questions_data):
            q, _ = Question.objects.get_or_create(quiz=quiz, text=text, defaults={"order": i + 1})
            for answer_text, is_correct in answers_data:
                Answer.objects.get_or_create(question=q, text=answer_text, defaults={"is_correct": is_correct})
