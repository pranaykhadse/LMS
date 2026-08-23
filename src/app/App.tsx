import { useState } from "react";
import heroBg from "@/imports/Acr28942341459202698019_copy.jpg";
import {
  Bell,
  ChevronDown,
  Star,
  CheckCircle,
  AlertCircle,
  BookOpen,
  Play,
  Linkedin,
  Library,
  Map,
  Award,
  MessageCircle,
  ChevronLeft,
  ChevronRight,
  CalendarDays,
  ArrowLeft,
} from "lucide-react";

const inProgressCourses = [
  {
    id: 1,
    category: "Article",
    title: "Introduction to AI",
    description: "Dive into the fundamentals of Artificial Intelligence and explore how intelligent systems work.",
    session: "Session 3 of 8",
    due: "August 12, 2026",
    progress: 35,
    image: "https://images.unsplash.com/photo-1759984782106-4b56d0aa05b8?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=600&q=80",
  },
  {
    id: 2,
    category: "One Pager",
    title: "How much AI do you know?",
    description: "Learn core testing principles, methodologies, and tools used in modern software development cycles.",
    session: "Session 1 of 6",
    due: "August 3, 2026",
    progress: 8,
    image: "https://images.unsplash.com/photo-1588702547954-4800ead296ef?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=600&q=80",
  },
  {
    id: 3,
    category: "Watch Video",
    title: "Effective Communication in the Workplace",
    description: "Master verbal, written, and non-verbal communication strategies for professional environments.",
    session: "Session 2 of 5",
    due: "August 28, 2026",
    progress: 52,
    image: "https://images.unsplash.com/photo-1588873281272-14886ba1f737?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=600&q=80",
  },
  {
    id: 4,
    category: "Learning Arcade Game",
    title: "Gamification in AI Learning",
    description: "Understand risk identification, assessment frameworks, and mitigation strategies in organizations.",
    session: "Session 4 of 7",
    due: "August 1, 2026",
    progress: 60,
    image: "https://images.unsplash.com/photo-1673515335586-f9f662c01482?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=600&q=80",
  },
  {
    id: 5,
    category: "Business Writing",
    title: "Virtual Email Format",
    description: "Learn professional email writing techniques to communicate clearly and effectively in remote work settings.",
    session: "Session 1 of 3",
    due: "August 20, 2026",
    progress: 20,
    image: "https://images.unsplash.com/photo-1673515334386-2b24073bb22f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=600&q=80",
  },
  {
    id: 6,
    category: "Diversity & Inclusion",
    title: "Introduction to Cultural Bridges",
    description: "Explore cultural differences and develop skills to collaborate across diverse teams and communities.",
    session: "Session 5 of 9",
    due: "August 15, 2026",
    progress: 72,
    image: "https://images.unsplash.com/photo-1509062522246-3755977927d7?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=600&q=80",
  },
  {
    id: 7,
    category: "Leadership",
    title: "Foundations of Team Leadership",
    description: "Build essential leadership skills to motivate teams, resolve conflict, and drive performance effectively.",
    session: "Session 2 of 6",
    due: "June 10, 2026",
    progress: 18,
    image: "https://images.unsplash.com/photo-1519389950473-47ba0277781c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=600&q=80",
  },
];

const courseProgress = [
  { name: "Introduction to Software Testing", percent: 8 },
  { name: "Managing Your Performance", percent: 0 },
];

const allRequiredCourses = [
  { id: 1, title: "Welcome to Holistic Balanced Solutions", image: "https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=400&q=80" },
  { id: 2, title: "Banner Testing Course 1", image: "https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=400&q=80" },
  { id: 3, title: "Prerequisite", image: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80" },
  { id: 4, title: "Kanchan QA Test", image: "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=400&q=80" },
  { id: 5, title: "xyz", image: "https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=400&q=80" },
  { id: 6, title: "Required Course 8", image: "https://images.unsplash.com/photo-1521737604893-d14cc237f11d?w=400&q=80" },
  { id: 7, title: "Required Course Final Test", image: "https://images.unsplash.com/photo-1606326608606-aa0b62935f2b?w=400&q=80" },
  { id: 8, title: "Required Course-4", image: "https://images.unsplash.com/photo-1553877522-43269d4ea984?w=400&q=80" },
  { id: 9, title: "Effective Communication in the Workplace", image: "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&q=80" },
  { id: 10, title: "Introduction to Cultural Bridges", image: "https://images.unsplash.com/photo-1531206715517-5c0ba140b2b8?w=400&q=80" },
  { id: 11, title: "Virtual Email Format", image: "https://images.unsplash.com/photo-1596526131083-e8c633c948d2?w=400&q=80" },
  { id: 12, title: "Introduction to Risk Management", image: "https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=400&q=80" },
  { id: 13, title: "Pre-test Risk Assessment (JSAJRA)", image: "https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=400&q=80" },
];

const requiredCourses = [
  "Effective Communication in the Workplace",
  "Introduction to Cultural Bridges",
  "Virtual Email Format",
  "Introduction to Risk Management",
  "Pre-test Risk Assessment (JSAJRA)",
];

const navLinks = [
  "Course Catalog",
  "My Courses",
  "Learning Paths",
  "Points & Badges",
  "Contact a Coach",
];

export default function App() {
  const [activeNav, setActiveNav] = useState("My Courses");
  const [carouselIndex, setCarouselIndex] = useState(0);
  const [showViewAll, setShowViewAll] = useState(false);
  const [showMentorModal, setShowMentorModal] = useState(false);
  const [showRequiredCourses, setShowRequiredCourses] = useState(false);
  const [requiredCoursesPage, setRequiredCoursesPage] = useState(1);
  const [showCourseProgress, setShowCourseProgress] = useState(false);
  const [mentorForm, setMentorForm] = useState({ firstName: "", lastName: "", email: "" });
  const prevSlide = () => setCarouselIndex((i) => Math.max(i - 1, 0));
  const nextSlide = () => setCarouselIndex((i) => Math.min(i + 1, inProgressCourses.length - 1));
  const currentCourse = inProgressCourses[carouselIndex];

  if (showViewAll) {
    return (
      <div className="min-h-screen bg-[#f4f5f7]" style={{ fontFamily: "'Inter', sans-serif", width: "1440px", margin: "0 auto" }}>
        {/* Top Bar */}
        <div className="bg-[#1a1a2e] text-white text-base flex items-center justify-between px-4 py-1.5">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-red-500 inline-block"></span>
            <span className="text-gray-300">Hippocampus</span>
            <span className="w-2 h-2 rounded-full bg-red-500 inline-block ml-1"></span>
          </div>
          <div className="flex items-center gap-4">
            <span className="text-gray-400">Tuesday July 23, 2024 | 6:11 PM</span>
            <Bell size={14} className="text-gray-300" />
            <div className="flex items-center gap-1.5 bg-[#2d2d4a] rounded px-2 py-0.5">
              <div className="w-5 h-5 rounded-full bg-purple-500 flex items-center justify-center text-[11px] font-bold">A</div>
              <span className="text-gray-200 text-base">Ayushi Gupta</span>
              <ChevronDown size={11} className="text-gray-400" />
            </div>
          </div>
        </div>

        {/* Page Content */}
        <div className="w-[1440px] mx-auto px-6 py-8">
          {/* Back button + Title */}
          <div className="flex items-center gap-3 mb-6">
            <button
              onClick={() => setShowViewAll(false)}
              className="flex items-center gap-1.5 text-base font-semibold text-[#5b5bd6] hover:opacity-70 transition-opacity"
            >
              <ArrowLeft size={14} />
              Back
            </button>
            <span className="text-gray-300">|</span>
            <h2 className="text-xl font-semibold text-gray-800">In-Progress Courses</h2>
            <span className="text-base text-gray-400 bg-gray-100 rounded-full px-2.5 py-0.5">{inProgressCourses.length} courses</span>
          </div>

          {/* Table */}
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            {/* Table Header */}
            <div className="grid grid-cols-[3rem_1fr_180px_140px] gap-0 px-6 py-3 border-b border-gray-100 bg-gray-50">
              <span className="text-[12px] font-semibold text-gray-400 uppercase tracking-wider">#</span>
              <span className="text-[12px] font-semibold text-gray-400 uppercase tracking-wider">Course Details</span>
              <span className="text-[12px] font-semibold text-gray-400 uppercase tracking-wider">Due Date</span>
              <span className="text-[12px] font-semibold text-gray-400 uppercase tracking-wider">Status</span>
            </div>

            {/* Rows */}
            {inProgressCourses.map((course, i) => (
              <div
                key={course.id}
                className="grid grid-cols-[3rem_1fr_180px_140px] gap-0 px-6 py-4 border-b border-gray-100 hover:bg-[#f8f8ff] transition-colors items-center"
              >
                {/* # */}
                <span className="text-base text-gray-400 font-medium">{i + 1}</span>

                {/* Course Details */}
                <div>
                  <p className="text-base font-semibold text-gray-800 leading-snug">{course.title}</p>
                  <p className="text-base text-gray-400 mt-0.5">{course.category}</p>
                </div>

                {/* Due Date */}
                <div className="flex items-center gap-1.5">
                  <CalendarDays size={12} className="text-[#5b5bd6]" />
                  <span className="text-base text-gray-600">{course.due}</span>
                </div>

                {/* Status */}
                <span className="inline-flex items-center px-3 py-1 rounded-full text-base font-semibold bg-[#ebebff] text-[#5b5bd6] w-fit">
                  In Progress
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (showCourseProgress) {
    const allCourses = inProgressCourses.map((c) => ({ name: c.title, percent: c.progress, category: c.category, due: c.due }));
    return (
      <div className="min-h-screen bg-[#f4f5f7]" style={{ fontFamily: "'Inter', sans-serif", width: "1440px", margin: "0 auto" }}>
        {/* Top Bar */}
        <div className="bg-[#1a1a2e] text-white text-xs flex items-center justify-between px-4 py-1.5">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-red-500 inline-block"></span>
            <span className="text-gray-300">Hippocampus</span>
            <span className="w-2 h-2 rounded-full bg-red-500 inline-block ml-1"></span>
          </div>
          <div className="flex items-center gap-4">
            <span className="text-gray-400">Tuesday July 23, 2024 | 6:11 PM</span>
            <Bell size={14} className="text-gray-300" />
            <div className="flex items-center gap-1.5 bg-[#2d2d4a] rounded px-2 py-0.5">
              <div className="w-5 h-5 rounded-full bg-purple-500 flex items-center justify-center text-[9px] font-bold">A</div>
              <span className="text-gray-200 text-xs">Ayushi Gupta</span>
              <ChevronDown size={11} className="text-gray-400" />
            </div>
          </div>
        </div>

        {/* Page Content */}
        <div className="w-[1440px] mx-auto px-6 py-8">
          {/* Back + Title */}
          <div className="flex items-center gap-3 mb-6">
            <button
              onClick={() => setShowCourseProgress(false)}
              className="flex items-center gap-1.5 text-xs font-semibold text-[#5b5bd6] hover:opacity-70 transition-opacity"
            >
              <ArrowLeft size={14} />
              Back
            </button>
            <span className="text-gray-300">|</span>
            <h2 className="text-base font-semibold text-gray-800">All Course Progress</h2>
            <span className="text-xs text-gray-400 bg-gray-100 rounded-full px-2.5 py-0.5">{allCourses.length} courses</span>
          </div>

          {/* Table */}
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <div className="grid grid-cols-[3rem_1fr_160px_140px] gap-0 px-6 py-3 border-b border-gray-100 bg-gray-50">
              <span className="text-[10px] font-semibold text-gray-400 uppercase tracking-wider">#</span>
              <span className="text-[10px] font-semibold text-gray-400 uppercase tracking-wider">Course</span>
              <span className="text-[10px] font-semibold text-gray-400 uppercase tracking-wider">Category</span>
              <span className="text-[10px] font-semibold text-gray-400 uppercase tracking-wider">Due Date</span>
            </div>
            {allCourses.map((course, i) => (
              <div key={course.name} className="grid grid-cols-[3rem_1fr_160px_140px] gap-0 px-6 py-4 border-b border-gray-100 hover:bg-[#f8f8ff] transition-colors items-center">
                <span className="text-sm text-gray-400 font-medium">{i + 1}</span>
                <p className="text-sm font-semibold text-gray-800">{course.name}</p>
                <span className="text-xs text-gray-400">{course.category}</span>
                <div className="flex items-center gap-1.5">
                  <CalendarDays size={12} className="text-[#5b5bd6]" />
                  <span className="text-xs text-gray-600">{course.due}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (showRequiredCourses) {
    const perPage = 8;
    const totalPages = Math.ceil(allRequiredCourses.length / perPage);
    const pageCourses = allRequiredCourses.slice((requiredCoursesPage - 1) * perPage, requiredCoursesPage * perPage);

    return (
      <div className="min-h-screen bg-white" style={{ fontFamily: "'Inter', sans-serif", width: "1440px", margin: "0 auto" }}>
        {/* Top Bar */}
        <div className="bg-[#1a1a2e] text-white text-base flex items-center justify-between px-4 py-1.5">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-red-500 inline-block"></span>
            <span className="text-gray-300">Hippocampus</span>
            <span className="w-2 h-2 rounded-full bg-red-500 inline-block ml-1"></span>
          </div>
          <div className="flex items-center gap-4">
            <span className="text-gray-400">Tuesday July 23, 2024 | 6:11 PM</span>
            <Bell size={14} className="text-gray-300" />
            <div className="flex items-center gap-1.5 bg-[#2d2d4a] rounded px-2 py-0.5">
              <div className="w-5 h-5 rounded-full bg-purple-500 flex items-center justify-center text-[11px] font-bold">A</div>
              <span className="text-gray-200 text-base">Ayushi Gupta</span>
              <ChevronDown size={11} className="text-gray-400" />
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav className="bg-white border-b border-gray-200 px-6">
          <div className="flex items-center gap-0">
            {["Course Catalog", "My Courses", "Learning Paths", "Points & Badges", "Contact a Coach"].map((link) => (
              <button key={link} className="flex items-center gap-1 px-4 py-3.5 text-base font-medium transition-colors text-gray-500 hover:text-gray-700">
                {link}
              </button>
            ))}
          </div>
        </nav>

        {/* Page Content */}
        <div className="px-8 py-8">
          {/* Back + Title */}
          <div className="flex items-center gap-3 mb-6">
            <button
              onClick={() => { setShowRequiredCourses(false); setRequiredCoursesPage(1); }}
              className="flex items-center gap-1.5 text-base font-semibold text-[#5b5bd6] hover:opacity-70 transition-opacity"
            >
              <ArrowLeft size={14} />
              Back
            </button>
            <span className="text-gray-300">|</span>
            <h2 className="text-xl font-semibold" style={{ color: "#5b5bd6" }}>My Required Courses</h2>
          </div>

          {/* Course Grid */}
          <div className="grid grid-cols-4 gap-6 mb-10">
            {pageCourses.map((course) => (
              <div key={course.id} className="bg-white rounded-[14px] border border-[#e5e7eb] overflow-hidden hover:shadow-md transition-shadow flex flex-col">
                {/* Image */}
                <div className="h-[224px] shrink-0 bg-[#f3f4f6] overflow-hidden">
                  <img
                    src={course.image}
                    alt={course.title}
                    className="w-full h-full object-cover"
                  />
                </div>
                {/* Content */}
                <div className="flex flex-col items-center p-[16px] h-[160px]">
                  <p className="w-full font-semibold text-[16px] leading-[22px] text-[#1e2939] flex-1">{course.title}</p>
                  <button className="h-[40px] w-[268px] bg-[#f8fafc] rounded-[8px] border border-[#5b5bd6] text-[#5b5bd6] text-[12px] font-semibold hover:bg-[#5b5bd6] hover:text-white transition-colors mt-auto mb-[16px]">
                    View Course
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* Pagination */}
          <div className="flex flex-col items-center gap-2">
            <div className="flex items-center gap-2">
              <button
                onClick={() => setRequiredCoursesPage((p) => Math.max(p - 1, 1))}
                disabled={requiredCoursesPage === 1}
                className="w-8 h-8 flex items-center justify-center rounded text-gray-400 hover:text-[#5b5bd6] disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
              >
                <ChevronLeft size={16} />
              </button>
              {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => (
                <button
                  key={page}
                  onClick={() => setRequiredCoursesPage(page)}
                  className={`w-8 h-8 rounded text-base font-medium transition-colors ${
                    page === requiredCoursesPage
                      ? "bg-[#5b5bd6] text-white"
                      : "text-gray-500 hover:text-[#5b5bd6]"
                  }`}
                >
                  {page}
                </button>
              ))}
              <button
                onClick={() => setRequiredCoursesPage((p) => Math.min(p + 1, totalPages))}
                disabled={requiredCoursesPage === totalPages}
                className="w-8 h-8 flex items-center justify-center rounded text-gray-400 hover:text-[#5b5bd6] disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
              >
                <ChevronRight size={16} />
              </button>
            </div>
            <p className="text-[12px] text-gray-400 uppercase tracking-widest">Page {requiredCoursesPage} of {totalPages}</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#f4f5f7]" style={{ fontFamily: "'Inter', sans-serif", width: "1440px", margin: "0 auto" }}>
      {/* Top Announcement Bar */}
      <div className="bg-[#1a1a2e] text-white text-base flex items-center justify-between px-4 py-1.5">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-red-500 inline-block"></span>
          <span className="text-gray-300">Hippocampus</span>
          <span className="w-2 h-2 rounded-full bg-red-500 inline-block ml-1"></span>
        </div>
        <div className="flex items-center gap-4">
          <span className="text-gray-400">Tuesday July 23, 2024 | 6:11 PM</span>
          <Bell size={14} className="text-gray-300" />
          <div className="flex items-center gap-1.5 bg-[#2d2d4a] rounded px-2 py-0.5">
            <div className="w-5 h-5 rounded-full bg-purple-500 flex items-center justify-center text-[11px] font-bold">A</div>
            <span className="text-gray-200 text-base">Ayushi Gupta</span>
            <ChevronDown size={11} className="text-gray-400" />
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="bg-white border-b border-gray-200 px-6">
        <div className="max-w-5xl mx-auto flex items-center gap-0">
          {navLinks.map((link) => (
            <button
              key={link}
              onClick={() => setActiveNav(link)}
              className={`flex items-center gap-1 px-4 py-3.5 text-xs font-normal transition-colors ${
                activeNav === link
                  ? "text-[#5b5bd6]"
                  : "text-gray-500 hover:text-gray-700"
              }`}
            >
              {{
                "Course Catalog": <Library size={13} className="flex-shrink-0" />,
                "My Courses": <BookOpen size={13} className="flex-shrink-0" />,
                "Learning Paths": <Map size={13} className="flex-shrink-0" />,
                "Points & Badges": <Award size={13} className="flex-shrink-0" />,
                "Contact a Coach": <MessageCircle size={13} className="flex-shrink-0" />,
              }[link]}
              {link}
              {link !== "Course Catalog" && link !== "Learning Paths" && (
                <ChevronDown size={11} className="opacity-60" />
              )}
            </button>
          ))}
        </div>
      </nav>


      {/* Main Content */}
      <div className="w-[1440px] mx-auto px-6 py-6 space-y-5">
        {/* Welcome Text */}
        <p className="text-base text-gray-500">
          Welcome back! Here&apos;s what&apos;s happening with your courses.
        </p>

        {/* Stats Row */}
        <div className="grid grid-cols-3 gap-3">
          {/* Enrolled */}
          <div className="bg-white rounded-lg border border-gray-200 px-5 py-4">
            <div className="flex items-center gap-1.5 mb-1">
              <BookOpen size={13} className="text-[#5b5bd6]" />
              <span className="text-[12px] font-semibold text-gray-400 uppercase tracking-wider">Enrolled</span>
            </div>
            <p className="text-4xl font-bold text-gray-800">2</p>
          </div>
          {/* Required */}
          <div className="bg-white rounded-lg border border-gray-200 px-5 py-4">
            <div className="flex items-center gap-1.5 mb-1">
              <AlertCircle size={13} className="text-amber-500" />
              <span className="text-[12px] font-semibold text-gray-400 uppercase tracking-wider">Required</span>
            </div>
            <p className="text-4xl font-bold text-gray-800">14</p>
          </div>
          {/* Completed */}
          <div className="bg-white rounded-lg border border-gray-200 px-5 py-4">
            <div className="flex items-center gap-1.5 mb-1">
              <CheckCircle size={13} className="text-green-500" />
              <span className="text-[12px] font-semibold text-gray-400 uppercase tracking-wider">Completed</span>
            </div>
            <p className="text-4xl font-bold text-gray-800">0</p>
          </div>
        </div>

        {/* Progress + Continue Learning Row */}
        <div className="grid grid-cols-2 gap-4">
          {/* Continue Learning */}
          {(() => {
            const isOverdue = new Date(currentCourse.due) < new Date();
            const accentColor = isOverdue ? "#dc2626" : "#5b5bd6";
            const accentHover = isOverdue ? "#b91c1c" : "#4a4abf";
            return (
              <div className={`bg-white rounded-lg overflow-hidden flex flex-col border ${isOverdue ? "border-red-200" : "border-gray-200"}`}>
                {/* Header */}
                <div className={`flex items-center justify-between px-5 pt-4 pb-3 border-b ${isOverdue ? "border-red-100 bg-red-50" : "border-gray-100"}`}>
                  <div className="flex items-center gap-2">
                    <p className="text-base font-semibold text-gray-500 uppercase tracking-wide">Continue Learning</p>
                    {isOverdue && (
                      <span className="text-[11px] font-bold text-white bg-red-500 px-2 py-0.5 rounded-full uppercase tracking-wide">Overdue</span>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    <button onClick={() => setShowViewAll(true)} className="text-base font-semibold text-[#5b5bd6] hover:opacity-70 transition-opacity ml-1">
                      View All
                    </button>
                  </div>
                </div>

                {/* Course Card */}
                <div className="flex flex-1 gap-0 cursor-pointer">
                  {/* Thumbnail */}
                  <div className="relative w-36 flex-shrink-0 overflow-hidden">
                    <img
                      src={currentCourse.image}
                      alt={currentCourse.title}
                      className="w-full h-full object-cover"
                    />
                  </div>

                  {/* Info */}
                  <div className="flex flex-1 items-center p-4 gap-4">
                    {/* Text details */}
                    <div className="flex flex-col justify-between flex-1 min-w-0">
                      <p className="text-[13px] font-semibold uppercase tracking-wide mb-0.5" style={{ color: accentColor }}>{currentCourse.category}</p>
                      <p className="text-base font-bold text-gray-800 leading-snug mb-1">{currentCourse.title}</p>
                      <p className="text-base text-gray-400 leading-relaxed mb-2 line-clamp-2">{currentCourse.description}</p>
                      <div className="flex items-center gap-1.5 mb-3">
                        <CalendarDays size={12} style={{ color: accentColor }} />
                        <span className="text-base font-medium" style={{ color: accentColor }}>
                          {isOverdue ? "Overdue: " : "Due: "}{currentCourse.due}
                        </span>
                      </div>
                      <button
                        className="self-start flex items-center gap-1.5 text-white text-base font-semibold px-4 py-2 rounded transition-colors"
                        style={{ background: accentColor }}
                        onMouseEnter={e => (e.currentTarget.style.background = accentHover)}
                        onMouseLeave={e => (e.currentTarget.style.background = accentColor)}
                      >
                        Resume Lesson →
                      </button>
                    </div>

                  </div>
                </div>

                {/* Dot indicators */}
                <div className="flex items-center justify-center gap-1.5 py-3 border-t border-gray-100">
                  {inProgressCourses.map((course, i) => {
                    const dot = new Date(course.due) < new Date();
                    return (
                      <button
                        key={i}
                        onClick={() => setCarouselIndex(i)}
                        className={`rounded-full transition-all duration-200 ${
                          i === carouselIndex
                            ? `w-4 h-1.5 ${dot ? "bg-red-500" : "bg-[#5b5bd6]"}`
                            : "w-1.5 h-1.5 bg-gray-300 hover:bg-gray-400"
                        }`}
                      />
                    );
                  })}
                </div>
              </div>
            );
          })()}

          {/* Upcoming Sessions */}
          <div className="bg-white rounded-lg border border-gray-200 p-5">
            <h3 className="text-base font-semibold text-gray-700 mb-4">Upcoming Sessions</h3>
            <div className="space-y-3">
              {[
                {
                  title: "Customer Service Excellence",
                  date: "Mon, Jul 28, 2026",
                  time: "10:00 AM – 11:00 AM EDT",
                  host: "Jonathan Fuentes",
                  link: "#",
                },
                {
                  title: "How to Make Yourself Indispensable",
                  date: "Wed, Jul 30, 2026",
                  time: "2:00 PM – 3:30 PM EDT",
                  host: "Christi Doporto",
                  link: "#",
                },
              ].map((session) => (
                <div key={session.title} className="rounded-lg border border-gray-100 bg-gray-50 p-3 hover:border-[#5b5bd6]/30 hover:bg-[#5b5bd6]/5 transition-colors">
                  <div className="flex items-start justify-between gap-2 mb-1.5">
                    <p className="text-base font-semibold text-gray-800 leading-snug">{session.title}</p>
                    <a
                      href={session.link}
                      className="flex-shrink-0 flex items-center gap-1 text-[12px] font-semibold text-white bg-[#5b5bd6] hover:bg-[#4a4abf] px-2.5 py-1 rounded transition-colors"
                    >
                      <span className="w-1.5 h-1.5 rounded-full bg-red-400 animate-pulse inline-block"></span>
                      Join
                    </a>
                  </div>
                  <div className="flex items-center gap-1.5 text-[12px] text-gray-400 mb-0.5">
                    <CalendarDays size={10} className="text-[#5b5bd6]" />
                    <span>{session.date}</span>
                    <span className="text-gray-300">•</span>
                    <span>{session.time}</span>
                  </div>
                  <p className="text-[12px] text-gray-400">Hosted by <span className="font-medium text-gray-600">{session.host}</span></p>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Course Progress + Overall Learning Progress */}
        <div className="grid grid-cols-2 gap-4">
          {/* Course Progress */}
          <div className="bg-white rounded-lg border border-gray-200 p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-base font-semibold text-gray-700">Course Progress</h3>
              <button
                onClick={() => setShowCourseProgress(true)}
                className="text-xs font-semibold text-[#5b5bd6] hover:opacity-70 transition-opacity"
              >
                View All
              </button>
            </div>
            <div className="space-y-4">
              {courseProgress.map((course) => (
                <div key={course.name}>
                  <div className="flex items-center justify-between mb-1.5">
                    <div className="flex items-center gap-2">
                      <BookOpen size={13} className="text-[#5b5bd6] flex-shrink-0" />
                      <span className="text-base text-gray-600">{course.name}</span>
                    </div>
                    <span className="text-base text-gray-400 font-medium">{course.percent}%</span>
                  </div>
                  <div className="w-full bg-gray-100 rounded-full h-1.5">
                    <div
                      className="bg-[#5b5bd6] rounded-full h-1.5"
                      style={{ width: `${course.percent}%` }}
                    ></div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Overall Learning Progress */}
          <div className="rounded-xl p-5 text-white" style={{ background: "linear-gradient(to right, #5865f2, #7c3aed)" }}>
            <div className="flex items-center gap-2 mb-3">
              <Star size={14} className="text-white opacity-90" />
              <span className="text-base font-semibold opacity-90 uppercase tracking-wide">Overall Learning Progress</span>
            </div>
            <p className="text-5xl font-bold mb-4">50%</p>
            <div className="w-full rounded-full h-1.5" style={{ background: "rgba(255,255,255,0.15)" }}>
              <div className="rounded-full h-1.5 w-1/2" style={{ background: "rgba(255,255,255,0.5)" }}></div>
            </div>
          </div>
        </div>

        {/* Required For You */}
        <div className="bg-white rounded-lg border border-gray-200 p-5">
          <h3 className="text-base font-semibold text-gray-700 mb-4">Required For You</h3>
          <div className="divide-y divide-gray-100">
            {requiredCourses.map((course, i) => (
              <div key={course} className="flex items-center justify-between py-3">
                <div className="flex items-center gap-3">
                  <span className="text-base text-gray-400 w-4 text-right">{i + 1}</span>
                  <span className="text-base text-gray-700">{course}</span>
                </div>
                <button className="text-[13px] text-[#5b5bd6] border border-[#5b5bd6] hover:bg-[#5b5bd6] hover:text-white px-3 py-1 rounded text-base font-medium transition-colors">
                  View
                </button>
              </div>
            ))}
          </div>
          <div className="mt-5 flex justify-center">
            <button onClick={() => setShowRequiredCourses(true)} className="bg-[#5b5bd6] hover:bg-[#4a4abf] text-white text-base font-semibold px-6 py-2.5 rounded transition-colors">
              View All Required Courses
            </button>
          </div>
        </div>

        {/* Footer */}
        <footer className="flex items-center justify-between py-3 border-t border-gray-200 text-[13px] text-gray-400">
          <div className="flex items-center gap-4">
            <a href="#" className="hover:text-gray-600 transition-colors">Terms of Use</a>
            <a href="#" className="hover:text-gray-600 transition-colors">Your Profile</a>
            <a href="#" className="hover:text-gray-600 transition-colors">Support</a>
          </div>
          <div className="flex items-center gap-4">
<a href="#" className="text-gray-500 hover:text-[#0077b5] transition-colors">
              <Linkedin size={16} />
            </a>
          </div>
        </footer>
      </div>

      {/* Confirm Mentor Modal */}
      {showMentorModal && (
        <div
          className="fixed inset-0 flex items-center justify-center z-50"
          style={{ background: "rgba(180,185,230,0.55)" }}
          onClick={(e) => { if (e.target === e.currentTarget) setShowMentorModal(false); }}
        >
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-md mx-4 p-8 relative">
            {/* Close */}
            <button
              onClick={() => setShowMentorModal(false)}
              className="absolute top-4 right-5 text-gray-400 hover:text-gray-600 text-xl font-light transition-colors"
            >
              ×
            </button>

            {/* Title */}
            <h2 className="text-2xl font-light text-gray-700 text-center mb-7 tracking-wide">Confirm Your Mentor</h2>

            {/* Fields */}
            <div className="space-y-5">
              <div>
                <label className="block text-base text-gray-700 mb-1.5">First Name</label>
                <input
                  type="text"
                  value={mentorForm.firstName}
                  onChange={(e) => setMentorForm({ ...mentorForm, firstName: e.target.value })}
                  className="w-full border border-gray-200 rounded-lg px-4 py-3 text-base text-gray-700 focus:outline-none focus:border-[#5b5bd6] transition-colors"
                />
              </div>
              <div>
                <label className="block text-base text-gray-700 mb-1.5">Last Name</label>
                <input
                  type="text"
                  value={mentorForm.lastName}
                  onChange={(e) => setMentorForm({ ...mentorForm, lastName: e.target.value })}
                  className="w-full border border-gray-200 rounded-lg px-4 py-3 text-base text-gray-700 focus:outline-none focus:border-[#5b5bd6] transition-colors"
                />
              </div>
              <div>
                <label className="block text-base text-gray-700 mb-1.5">Email</label>
                <input
                  type="email"
                  value={mentorForm.email}
                  onChange={(e) => setMentorForm({ ...mentorForm, email: e.target.value })}
                  className="w-full border border-gray-200 rounded-lg px-4 py-3 text-base text-gray-700 focus:outline-none focus:border-[#5b5bd6] transition-colors"
                />
              </div>
            </div>

            {/* Note */}
            <p className="text-base text-gray-500 italic mt-5 leading-relaxed">
              <span className="font-bold not-italic text-gray-600">Note:</span>{" "}
              We ask that you confirm your mentor&apos;s information every three months. If the above information is correct, click Confirm. You can edit your mentor&apos;s information at anytime through your profile.
            </p>

            {/* Confirm Button */}
            <div className="flex justify-center mt-6">
              <button
                onClick={() => setShowMentorModal(false)}
                className="bg-[#5b5bd6] hover:bg-[#4a4abf] text-white font-semibold px-12 py-3 rounded-xl transition-colors text-base"
              >
                Confirm
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
